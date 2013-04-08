angular.module('TrelloTasksApp').factory 'makeEventEmitter', ['$rootScope', '$timeout', ($rootScope, $timeout) ->
	(obj) ->
		handlers = {}
		obj.on = (name, handler) ->
			handlers[name] ?= []
			handlers[name].push handler
		obj.trigger = (name, args...) ->
			angular.forEach handlers[name] or [], (handler) ->
				$timeout () ->
					handler args...
		return obj
]

angular.module('TrelloTasksApp').factory 'Trello', ['$rootScope', '$timeout', '$q', 'makeEventEmitter', ($rootScope, $timeout, $q, makeEventEmitter) ->
	trello = makeEventEmitter({})

	trello.authorized = false

	$rootScope.$watch () -> console.log 'digested'

	get = (path, args...) ->
		params = {}
		shouldTriggerUpdates = true
		if _.isObject args[0]
			params = args[0]
			shouldTriggerUpdates = if args[1] == false then false else true
		else
			shouldTriggerUpdates = if args[0] == false then false else true

		deferred = $q.defer()
		Trello.get path, params, (result) ->
			if shouldTriggerUpdates
				$rootScope.$apply () ->
					deferred.resolve result
			else
				deferred.resolve result
		, (error) ->
			if shouldTriggerUpdates
				$rootScope.$apply () ->
					deferred.reject error
			else
				deferred.reject error

		return deferred.promise

	trello.authorize = (token) ->
		if token
			Trello.setToken token
		defer = $q.defer()
		Trello.authorize
			name: "Taskello"
			type: 'popup'
			interactive: !token
			persist: false
			success: () ->
				# Timeout because if this returns synchronously
				# $apply will already be in progress
				$timeout () ->
					trello.authorized = true
					trello.trigger 'authenticated'
					defer.resolve true
			error: () ->
				$timeout () ->
					trello.trigger 'unauthenticated'
					defer.reject true
		return defer.promise

	trello.getApiToken = () -> Trello.token()

	trello.me = {}
	trello.organizations = {
		'my': { displayName: "My Boards" }
	}
	trello.boards = {}
	trello.lists = {}
	trello.cards = {}

	mergeObject = (src, dst) ->
		if src == dst
			return dst

		angular.forEach src, (value, key) ->
			if key.charAt?(0) == '$'
				return
			if (_.isObject(value) && _.isObject(dst[key])) or
			 	(_.isArray(value) && _.isArray(dst[key]))
				mergeObject value, dst[key]
			else if dst[key] != value
				dst[key] = value

		if _.isArray(dst) && _.isArray(src)
			dst.length = src.length
		else
			angular.forEach dst, (value, key) ->
				if key.charAt?(0) == '$'
					return
				if _.isUndefined src[key]
					delete dst[key]
		return dst

	firstSync = true
	synchronize = () ->
		shouldTriggerUpdates = false
		if firstSync
			newOrganizations = trello.organizations
			newBoards = trello.boards
			newCards = trello.cards
			newLists = trello.lists
			newMe = trello.me
			firstSync = false
			shouldTriggerUpdates = true
		else
			newOrganizations = { 'my': { displayName: "My Boards" } }
			newBoards = {}
			newCards = {}
			newLists = {}
			newMe = {}

		$q.all([
			get('member/me/boards', { lists: 'open' }, shouldTriggerUpdates),
			get('member/me/organizations', shouldTriggerUpdates),
			get('member/me', shouldTriggerUpdates)
		])
		.then (results) ->
			boards = results[0]
			organizations = results[1]
			me = results[2]

			angular.copy me, newMe

			_.each organizations, (organization) ->
				newOrganizations[organization.id] = organization

			return $q.all(_.map boards, (board) ->
				if not board.idOrganization || not newOrganizations[board.idOrganization]
					board.idOrganization = 'my'

				newOrganizations[board.idOrganization].boards ?= []
				newOrganizations[board.idOrganization].boards.push board

				newBoards[board.id] = board
				_.each board.lists, (list) ->
					newLists[list.id] = list

				return get("board/#{board.id}/cards", shouldTriggerUpdates).then (cards) ->
					board.cards = cards
					_.each cards, (card) ->
						newLists[card.idList].cards ?= []
						newLists[card.idList].cards.push card
						newCards[card.id] = card
			)
		.then () ->
			mergeObject newOrganizations, trello.organizations
			mergeObject newBoards, trello.boards
			mergeObject newCards, trello.cards
			mergeObject newLists, trello.lists
			mergeObject newMe, trello.me

			trello.trigger 'cards-updated', trello.cards
			trello.trigger 'lists-updated', trello.lists
			trello.trigger 'boards-updated', trello.boards
			trello.trigger 'organizations-updated', trello.organizations


	timer = null
	synchronizeOnTimer = () ->
		synchronize().then () ->
			timer = $timeout synchronizeOnTimer, 30000

	trello.on 'authenticated', synchronizeOnTimer
	trello.on 'unauthenticated', () ->
		timer?.cancel()

	return trello
]
