nextTick = (fn) ->
	setTimeout fn, 0

angular.module('TrelloTasksApp').factory 'angularBurn', ['$q', '$serviceScope', ($q, $serviceScope) ->
	authClientFromReference = (reference) ->
		$scope = $serviceScope()

		authClient = new FirebaseAuthClient reference, (error, user) ->
			nextTick () ->
				$scope.$apply () ->
					if not user
						$scope.$emit 'unauthenticated', error
					else
						$scope.$emit 'authenticated', user

		$scope.login = (args...) -> authClient.login args...
		$scope.logout = (args...) -> authClient.logout args...

		$scope.createUser = (args...) ->
			deferred = $q.defer()
			authClient.createUser args..., (error, user) ->
				if error
					deferred.reject error
				else
					deferred.resolve user
			return deferred.promise

		return $scope

	clientFromReference = (reference, initialValue = []) ->
		$scope = $serviceScope()

		valueDeferred = $scope.$defer 'value'

		lastValue = null

		$applyNextTick = (fn) ->
			setTimeout () ->
				$scope.$apply fn
			, 0

		updateFromSnapshot = (snapshot) ->
			if not $scope.value
				$scope.value = angular.copy initialValue
				valueDeferred.resolve $scope.value

			angular.copy snapshot.val(), $scope.value
			lastValue = angular.copy $scope.value

		scopeWatchRemover = null
		startWatching = () ->
			reference.on 'value', (snapshot) ->
				$applyNextTick () ->
					updateFromSnapshot snapshot

			firstWatch = true
			scopeWatchRemover = $scope.$watch () ->
				if firstWatch
					firstWatch = false
					return

				if _.isUndefined($scope.value)
					return

				val = JSON.parse angular.toJson($scope.value)

				if not angular.equals(lastValue, val)
					reference.set val

		stopWatching = () ->
			scopeWatchRemover?()
			reference.off 'value'

		angular.extend $scope,
			_reference: reference
			authClient: () -> authClientFromReference(reference)
			child: (path, initialValue) ->
				childReference = reference.child path
				clientFromReference childReference, initialValue
			watch: startWatching
			stopWatching: stopWatching

		return $scope

	exports = {}
	exports.client = (url, initialValue) ->
		reference = new Firebase url
		clientFromReference reference, initialValue

	return exports
]
