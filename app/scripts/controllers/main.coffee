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

		setHeightOnInterval = () ->
			setHeight()
			$timeout setHeightOnInterval, 1000
		setHeightOnInterval()

		$(window).on 'resize', setHeight
]

angular.module('TrelloTasksApp').directive 'throttledModel', [() ->
	($scope, $element, $attr) ->
		triggerUpdate = _.debounce (value) ->
			$scope.$apply () ->
				$scope[$attr.throttledModel] = value
		, 50
		$element.on 'input', () ->
			triggerUpdate $element.val()
]


angular.module('TrelloTasksApp').controller 'MainCtrl', ['$scope', '$q', 'Trello', 'TrelloTasks', ($scope, $q, Trello, TrelloTasks) ->
	$scope.trelloTasks = TrelloTasks

	# Sets the default for each board, which each then get
	# their own scope and override
	$scope.isBoardCollapsed = false
	$scope.isOrganizationCollapsed = false

	$scope.organizations = Trello.organizations
	$scope.lists = Trello.lists
	$scope.boards = Trello.boards

	$scope.organizationHasMatchingCards = (organization, filterCriteria) ->
	 	_.any organization.boards, (board) ->
	 		$scope.boardHasMatchingCards board, filterCriteria

	cardMatches = (card, filterCriteria) ->
		if filterCriteria.justMe
			if _.indexOf(card.idMembers, Trello.me.id) == -1
				return false

		searchTerms = filterCriteria.searchTerms
		if !searchTerms || searchTerms == '' || !searchTerms.split
			return true

		return _.every _.toArray(searchTerms.split /\ /g), (searchTerm) ->
			searchRegex = ///#{searchTerm}///i
			if card.name.match searchRegex
				return true
			if Trello.lists[card.idList].name.match searchRegex
				return true
			if Trello.boards[card.idBoard].name.match searchRegex
				return true

			organizationId = Trello.boards[card.idBoard].idOrganization || 'my'
			if Trello.organizations[organizationId].displayName.match searchRegex
				return true
			return false

	hasMatchingCards = (cards, filterCriteria) ->
 		_.any cards, (card) -> cardMatches card, filterCriteria

 	$scope.boardHasMatchingCards = (board, filterCriteria) ->
 		hasMatchingCards board.cards, filterCriteria
 	$scope.listHasMatchingCards = (list, filterCriteria) ->
 		hasMatchingCards list.cards, filterCriteria
 	$scope.cardMatches = cardMatches
]
