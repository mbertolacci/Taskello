angular.module('TrelloTasksApp').factory 'angularBurn', ['$rootScope', '$q', '$timeout', ($rootScope, $q, $timeout) ->
	clientFromReference = (reference, initialValue = []) ->
		deferred = $q.defer()
		client = deferred.promise

		value = null
		lastValue = null

		scopeWatchRemover = null

		updateFromSnapshot = (snapshot) ->
			if not value
				value = angular.copy initialValue
				deferred.resolve value
			if snapshot.val()
				angular.copy snapshot.val(), value
			lastValue = angular.copy value

		startWatching = () ->
			reference.on 'value', (snapshot) ->
				$timeout () -> updateFromSnapshot snapshot

			firstWatch = true
			scopeWatchRemover = $rootScope.$watch () ->
				if firstWatch
					firstWatch = false
					return

				val = JSON.parse angular.toJson(value)

				if not angular.equals(lastValue, val)
					reference.set val

		stopWatching = () ->
			scopeWatchRemover?()
			reference.off 'value'

		angular.extend client,
			_reference: reference
			authClient: (cb) ->
				return new FirebaseAuthClient reference, (args...) ->
					$rootScope.$eval () -> cb args...
			child: (path, initialValue) ->
				childReference = reference.child path
				clientFromReference childReference, initialValue
			watch: startWatching
			stopWatching: stopWatching

		return client

	exports = {}
	exports.client = (url, initialValue) ->
		reference = new Firebase url
		clientFromReference reference, initialValue

	return exports
]
