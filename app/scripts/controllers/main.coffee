angular.module('TrelloTasksApp').directive 'fillParentHeight', ['$timeout', ($timeout) ->
	($scope, $element, $attrs) ->
		setMaxHeight = () ->
			parentOffset = $element.parent().offset()
			offset = $element.offset()
			parentHeight = $element.parent().height()
			$element.css
				'max-height': parentHeight - (offset.top - parentOffset.top)

		$element.parent().on 'resized', setMaxHeight
		$timeout setMaxHeight
]
angular.module('TrelloTasksApp').directive 'fillWindowHeight', ['$timeout', ($timeout) ->
	($scope, $element, $attrs) ->
		setHeight = () ->
			offset = $element.offset()
			windowHeight = $(window).height()
			marginBottom = parseInt $element.css('marginBottom')
			$element.css
				'height': windowHeight - offset.top - marginBottom
			$element.trigger 'resized'

		$(window).on 'resize', setHeight
		$timeout setHeight
]

angular.module('TrelloTasksApp').controller 'MainCtrl', ['$scope', '$q', 'Trello', 'TrelloTasks', ($scope, $q, Trello, TrelloTasks) ->
	$scope.trelloTasks = TrelloTasks

	# Sets the default for each board, which each then get
	# their own scope and override
	$scope.isBoardCollapsed = false
	$scope.isOrganizationCollapsed = true

	$scope.organizations = Trello.organizations
	$scope.lists = Trello.lists
	$scope.boards = Trello.boards

	$scope.organizationHasCards = (organization) ->
	 	_.any organization.boards, (board) -> board?.cards?.length
	$scope.boardHasCards = (board) -> board?.cards?.length


]
