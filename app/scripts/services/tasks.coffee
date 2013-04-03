angular.module('TrelloTasksApp').factory 'Tasks', ['$window', '$rootScope', '$timeout', '$q', 'makeEventEmitter', ($window, $rootScope, $timeout, $q, makeEventEmitter) ->
	tasks = makeEventEmitter {}

	taskDeferred = $q.defer()
	trelloAccountDeferred = $q.defer()

	tasks.user = null
	tasks.authenticationState = 'unknown'
	tasks.lastAuthenticationError = {}

	firebaseReference = new Firebase "https://trellotasks.firebaseio.com/users"

	authClient = new FirebaseAuthClient firebaseReference, (error, user) ->
		if user
			tasks.user = user
			tasks.authenticationState = 'authenticated'

			angular.copy {}, tasks.lastAuthenticationError
			tasks.trigger 'authenticated'
		else
			tasks.user = null
			tasks.authenticationState = 'unauthenticated'
			angular.copy error, tasks.lastAuthenticationError
			tasks.trigger 'unauthenticated', error

	taskReferenceWatcher = null
	trelloAccountWatcher = null
	tasks.on 'authenticated', () ->
		if not taskReferenceWatcher
			taskReference = firebaseReference.child "#{tasks.user.id}/tasks"
			taskReferenceWatcher = watchReference taskReference, taskDeferred, $rootScope

			trelloAccount = firebaseReference.child "#{tasks.user.id}/trelloAccount"
			trelloAccountWatcher = watchReference trelloAccount, trelloAccountDeferred, $rootScope, {}

		taskReferenceWatcher.watch()
		trelloAccountWatcher.watch()

	tasks.on 'unauthenticated', (error) ->
		taskReferenceWatcher?.stopWatching()
		trelloAccountWatcher?.stopWatching()

	tasks.getTaskCards = () -> taskDeferred.promise
	tasks.getTrelloToken = () ->
		trelloAccountDeferred.promise.then (trelloAccount) ->
			trelloAccount.apiToken

	tasks.setTrelloToken = (token) ->
		trelloAccountDeferred.promise.then (trelloAccount) ->
			trelloAccount.apiToken = token

	tasks.logout = () ->
		taskReferenceWatcher.stopWatching()
		authClient.logout()
	tasks.login = (credentials) ->
		authClient.login 'password',
			email: credentials.email
			password: credentials.password

	tasks.createUser = (credentials) ->
		deferred = $q.defer()
		authClient.createUser credentials.email, credentials.password, (error, user) ->
			if not error
				tasks.login credentials
				deferred.resolve()
			else
				deferred.reject()
				$rootScope.$apply () ->
					angular.copy error, tasks.lastAuthenticationError
		return deferred.promise

	return tasks
]

angular.module('TrelloTasksApp').factory 'TrelloTasks', ['$timeout', '$rootScope', 'makeEventEmitter', 'Trello', 'Tasks', ($timeout, $rootScope, makeEventEmitter, Trello, Tasks) ->
	trelloTasks = makeEventEmitter {}

	trelloTasks.authenticationState = 'unknown'

	trelloTasks.lastAuthenticationError = Tasks.lastAuthenticationError

	updateAuthState = () ->
		trelloTasks.user = Tasks.user

		if Tasks.authenticationState == 'unknown'
			trelloTasks.authenticationState = 'unknown'
		else if Tasks.authenticationState != 'authenticated'
			if trelloTasks.authenticating
				trelloTasks.authenticationState = 'authenticating'
			else
				trelloTasks.authenticationState = 'unauthenticated'
		else if not Trello.authorized
			if trelloTasks.authenticating
				trelloTasks.authenticationState = 'authenticating'
			else
				trelloTasks.authenticationState = 'needTrello'
		else
			trelloTasks.authenticationState = 'authenticated'
	
	Trello.on 'unauthenticated', updateAuthState
	Tasks.on 'unauthenticated', updateAuthState

	Trello.on 'authenticated', () ->
		Tasks.setTrelloToken Trello.getApiToken()
		updateAuthState()
	Tasks.on 'authenticated', () ->
		trelloTasks.authenticating = true
		Tasks.getTrelloToken().then (trelloToken) ->
			if trelloToken
				trelloTasks.authenticating = true
				Trello.authorize(trelloToken).then () ->
					trelloTasks.authenticating = false
				, () ->
					trelloTasks.authenticating = false
			else
				trelloTasks.authenticating = false
			updateAuthState()
		updateAuthState()

	updateAuthState()

	trelloTasks.taskCards = Tasks.getTaskCards()

	Trello.on 'cards-updated', (cards) ->
		trelloTasks.taskCards.then (taskCards) ->
			currentCardIds = {}
			_.each cards, (card) ->
				taskCard = _.findWhere taskCards, { id: card.id }
				if taskCard
					angular.copy card, taskCard
					currentCardIds[taskCard.id] = true

			# Clear out the cards that are no longer current
			currentCards = _.filter taskCards, (card) -> currentCardIds[card.id]
			angular.copy currentCards, taskCards

	trelloTasks.createUser = (email, password) ->
		trelloTasks.creatingUser = true
		Tasks.createUser
			email: email
			password: password
		.then () -> 
			trelloTasks.creatingUser = false
		, () ->
			trelloTasks.creatingUser = false


	trelloTasks.signIn = (email, password) ->
		trelloTasks.authenticating = true
		Tasks.login
			email: email
			password: password

	trelloTasks.signOut = () ->
		Tasks.logout()

	trelloTasks.connectTrello = () ->
		Trello.authorize()

	return trelloTasks
]

watchReference = (firebaseReference, deferred, $rootScope, initialValue = []) ->
	watching = false

	value = null
	initial = true
	lastValue = null

	updateFromSnapshot = (snapshot) ->
		if not value
			value = initialValue
			deferred.resolve value
		if snapshot.val()
			angular.copy snapshot.val(), value
		lastValue = angular.copy value

	firebaseReference.on 'value', (snapshot) ->
		if $rootScope.$$phase == '$apply' or $rootScope.$$phase == '$digest'
			updateFromSnapshot snapshot
		else
			$rootScope.$apply () ->	updateFromSnapshot snapshot

	$rootScope.$watch () ->
		if initial
			initial = false
			return

		return if not watching

		val = JSON.parse angular.toJson(value)

		if not angular.equals(lastValue, val)
			firebaseReference.set val

	return {
		watch: () -> watching = true
		stopWatching: () -> watching = false
	}