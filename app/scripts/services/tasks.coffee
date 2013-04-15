angular.module('TrelloTasksApp').factory 'Tasks', ['$window', '$rootScope', '$timeout', '$serviceScope', 'angularBurn', ($window, $rootScope, $timeout, $serviceScope, angularBurn) ->
	$scope = $serviceScope()

	$scope.user = null
	$scope.authenticationState = 'unknown'
	$scope.lastAuthenticationError = {}

	$scope.taskCards = null
	$scope.trelloApiToken = null

	usersClient = angularBurn.client "https://trellotasks.firebaseio.com/users"
	authClient = usersClient.authClient()

	taskCardsDeferred = $scope.$defer 'taskCards'
	trelloAccountDeferred = $scope.$defer 'trelloAccount'

	authClient.$on 'unauthenticated', (event, error) ->
		$scope.lastAuthenticationError = error
		$scope.authenticationState = 'unauthenticated'
		$scope.$emit 'unauthenticated'


	tasksClient = null
	trelloAccountClient = null
	authClient.$on 'authenticated', (event, user) ->
		if not tasksClient
			tasksClient = usersClient.child "#{user.id}/tasks", []
			trelloAccountClient = usersClient.child "#{user.id}/trelloAccount", {}

		tasksClient.watch()
		trelloAccountClient.watch()

		$scope.user = user

		taskCardsDeferred.resolve tasksClient.$get('value')
		trelloAccountDeferred.resolve trelloAccountClient.$get('value')

		tasksClient.$attachProperty('value', $scope, 'taskCards')
		trelloAccountClient.$attachProperty('value', $scope, 'trelloAccount')

		$scope.authenticationState = 'authenticated'
		$scope.$emit 'authenticated'

	$scope.logout = () ->
		tasksClient.stopWatching()
		trelloAccountClient.stopWatching()

		authClient.logout()
	$scope.login = (credentials) ->
		$scope.authenticationState = 'authenticating'

		authClient.login 'password',
			email: credentials.email
			password: credentials.password

	$scope.createUser = (credentials) ->
		authClient
		.createUser(credentials.email, credentials.password)
		.then (user) ->
			$scope.login credentials
		, (error) ->
			$scope.$apply () ->
				$scope.lastAuthenticationError = error

	return $scope
]

angular.module('TrelloTasksApp').factory 'TrelloTasks', ['$timeout', '$rootScope', '$serviceScope', 'Trello', 'Tasks', ($timeout, $rootScope, $serviceScope, Trello, Tasks) ->
	$scope = $serviceScope()

	$scope.authenticationState = 'unknown'

	$scope.lastAuthenticationError = Tasks.lastAuthenticationError

	updateAuthState = () ->
		$scope.user = Tasks.user

		states =
			# Task level
			unknown: 'unknown'
			authenticating: 'authenticating'
			unauthenticated: 'unauthenticated'
			authenticated:
				# Trello level
				unknown: 'authenticating'
				authenticating: 'authenticating'
				unauthenticated: 'needTrello'
				authenticated: 'authenticated'

		firstState = states[Tasks.authenticationState]

		if not _.isObject(firstState)
			$scope.authenticationState = firstState
		else
			$scope.authenticationState = firstState[Trello.authenticationState]

		console.log "New state is #{$scope.authenticationState}"

	Trello.$on 'unauthenticated', updateAuthState
	Tasks.$on 'unauthenticated', updateAuthState
	Trello.$on 'authenticated', updateAuthState
	Tasks.$on 'authenticated', updateAuthState

	Trello.$on 'authenticated', () ->
		Tasks.$evalAsync () ->
			Tasks.trelloAccount.apiToken = Trello.getApiToken()
	
	Tasks.$on 'authenticated', () ->
		Tasks.$get('trelloAccount').then () ->
			trelloApiToken = Tasks.trelloAccount.apiToken
			if not trelloApiToken
				Trello.authenticationState = 'unauthenticated'
			else
				Trello.authorize(trelloApiToken)

			updateAuthState()
		updateAuthState()

	updateAuthState()

	Tasks.$attachProperty('taskCards', $scope, 'taskCards')

	Trello.$on 'cards-updated', (event, cards) ->
		Tasks.$get('taskCards').then () ->
			currentCardIds = {}

			_.each cards, (card) ->
				taskCard = _.findWhere $scope.taskCards, { id: card.id }
				if taskCard
					angular.copy card, taskCard
					currentCardIds[taskCard.id] = true

			# Clear out the cards that are no longer current
			currentCards = _.filter $scope.taskCards, (card) -> currentCardIds[card.id]

			$scope.$update 'taskCards', currentCards

	Tasks.$get('taskCards').then () ->
		$scope.inTaskList = (card) ->
			!!_.findWhere Tasks.taskCards, { id: card.id }

	$scope.createUser = (email, password) ->
		$scope.creatingUser = true
		Tasks.createUser
			email: email
			password: password
		.then () -> 
			$scope.creatingUser = false
		, () ->
			$scope.creatingUser = false

	$scope.signIn = (email, password) ->
		$scope.authenticating = true
		Tasks.login
			email: email
			password: password

	$scope.signOut = () ->
		Tasks.logout()

	$scope.connectTrello = () ->
		Trello.authorize()

	return $scope
]
