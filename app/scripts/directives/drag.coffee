angular.module('TrelloTasksApp').directive 'sortable', [() ->
  return {
    require: '?ngModel',
    link: ($scope, $element, $attrs, ngModel) ->
      opts = angular.extend({}, $scope.$eval($attrs.sortable));

      ngModel.$render = () -> $element.sortable "refresh"

      leftSortable = false

      $element.sortable(opts)

      .on 'sortstart', (event, ui) ->
        if not ui.item.model
          modelFromHelper = $(ui.helper).data 'model'
          if modelFromHelper
            ui.item.model = modelFromHelper
            ui.item.fromElsewhere = true

        if not ui.item.model
          ui.item.model = ngModel.$modelValue[ui.item.index()]

      .on 'sortstop', (event, ui) ->
        wasDropped = $(ui.item).data 'dropped'
        if ui.item.model
          currentIndex = _.indexOf ngModel.$modelValue, ui.item.model
          newIndex = ui.item.index()

          if wasDropped
            # Remove it, it's gone
            ngModel.$modelValue.splice currentIndex, 1
          else
            if currentIndex == newIndex
              return

            if currentIndex != -1
              ngModel.$modelValue.splice currentIndex, 1
            ngModel.$modelValue.splice newIndex, 0, ui.item.model

        # Remove the current item to ng-repeat to redraw it
        $(ui.item).remove()
        $scope.$apply()
  }
]

angular.module('TrelloTasksApp').directive 'draggable', [() ->
  return {
    require: '?ngModel',
    link: ($scope, $element, $attrs, ngModel) ->
      opts = angular.extend({}, $scope.$eval($attrs.draggable));

      $element.draggable(opts)
      .on 'dragstart', (event, ui) ->
        $(ui.helper).data 'model', ngModel.$modelValue
  }
]
angular.module('TrelloTasksApp').directive 'droppable', [() ->
  return {
    link: ($scope, $element, $attrs) ->
      opts = angular.extend({}, $scope.$eval($attrs.droppable));

      $element.droppable(opts)
      .on 'drop', (event, ui) ->
        $(ui.draggable).data 'dropped', true
  }
]