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

angular.module('TrelloTasksApp').factory 'Trello', ['$timeout', '$serviceQ', '$serviceScope', 'makeEventEmitter', ($timeout, $serviceQ, $serviceScope, makeEventEmitter) ->
	$scope = $serviceScope('trello')

	$scope.authenticationState = 'unknown'

	get = (path, args...) ->
		params = {}
		shouldTriggerUpdates = true
		if _.isObject args[0]
			params = args[0]
			shouldTriggerUpdates = if args[1] == false then false else true
		else
			shouldTriggerUpdates = if args[0] == false then false else true

		deferred = $serviceQ.defer()
		Trello.get path, params, (result) ->
			if shouldTriggerUpdates
				$scope.$apply () ->
					deferred.resolve result
			else
				deferred.resolve result
		, (error) ->
			if shouldTriggerUpdates
				$scope.$apply () ->
					deferred.reject error
			else
				deferred.reject error

		return deferred.promise

	$scope.authorize = (token) ->
		if token
			Trello.setToken token
		defer = $serviceQ.defer()

		$scope.authenticationState = 'authenticating'
		# Timeout because if this returns synchronously
		# $apply will already be in progress
		setTimeout () ->
			Trello.authorize
				name: "Taskello"
				type: 'popup'
				interactive: !token
				persist: false
				success: () ->
					$scope.$apply () ->
						$scope.authenticationState = 'authenticated'
						$scope.$emit 'authenticated'
						defer.resolve true
				error: () ->
					$scope.$apply () ->
						$scope.authenticationState = 'unauthenticated'
						$scope.$emit 'unauthenticated'
						defer.reject true
		, 0
		return defer.promise

	$scope.getApiToken = () -> Trello.token()

	$scope.me = {}
	$scope.organizations = {
		'my': { displayName: "My Boards" }
	}
	$scope.boards = {}
	$scope.lists = {}
	$scope.cards = {}

	firstSync = true
	synchronize = () ->
		$scope.synchronizing = true

		shouldTriggerUpdates = false
		if firstSync
			newOrganizations = $scope.organizations
			newBoards = $scope.boards
			newCards = $scope.cards
			newLists = $scope.lists
			newMe = $scope.me
			firstSync = false
			shouldTriggerUpdates = true
		else
			newOrganizations = { 'my': { displayName: "My Boards" } }
			newBoards = {}
			newCards = {}
			newLists = {}
			newMe = {}

		$serviceQ.all([
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

			return $serviceQ.all(_.map boards, (board) ->
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
			$scope.$apply () ->
				$scope.synchronizing = false
				$scope.$update 'organizations', newOrganizations
				$scope.$update 'boards', newBoards
				$scope.$update 'cards', newCards
				$scope.$update 'lists', newLists
				$scope.$update 'me', newMe

			$scope.$emit 'cards-updated', $scope.cards
			$scope.$emit 'lists-updated', $scope.lists
			$scope.$emit 'boards-updated', $scope.boards
			$scope.$emit 'organizations-updated', $scope.organizations


	timer = null
	synchronizeOnTimer = () ->
		synchronize().then () ->
			timer = $timeout synchronizeOnTimer, 30000

	$scope.$on 'authenticated', synchronizeOnTimer
	$scope.$on 'unauthenticated', () ->
		timer?.cancel()

	return $scope
]
