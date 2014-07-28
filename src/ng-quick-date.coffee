#
# ngQuickDate
# by Adam Albrecht
# http://adamalbrecht.com
#
# Source Code: https://github.com/adamalbrecht/ngQuickDate
#
# Updated to append to body and reuse a singe element by Wyatt Nielsen
#
# Source: https://github.com/WyattNielsen/ngQuickDate.git
#
# Compatible with Angular 1.2.0+
#

app = angular.module("ngQuickDate", [])

app.provider "ngQuickDate", ->
  quickDate: null
  options:
    dateFormat: 'M/d/yyyy'
    timeFormat: 'h:mm a'
    labelFormat: null
    placeholder: 'Click to Set Date'
    hoverText: null
    buttonIconHtml: null
    closeButtonHtml: '&times;'
    nextLinkHtml: 'Next &rarr;'
    prevLinkHtml: '&larr; Prev'
    disableTimepicker: false
    disableClearButton: false
    defaultTime: null
    dayAbbreviations: ["Su", "M", "Tu", "W", "Th", "F", "Sa"],
    dateFilter: null
    parseDateFunction: (str) ->
      seconds = Date.parse(str)
      if isNaN(seconds)
        return null
      else
        new Date(seconds)

  $get: [ "$document", "$compile", "$rootScope", "$timeout", "$sce", "$filter", ($document, $compile, $rootScope, $timeout, $sce, $filter) ->
    return if @quickDate then @quickDate else @quickDate = new QuickDate($document, $compile, $rootScope, $timeout, $sce, $filter, @options)
  ]

  set: (keyOrHash, value) ->
    return @quickDate.set(keyOrHash) if @quickDate?
    if typeof(keyOrHash) == 'object'
      for k, v of keyOrHash
        @options[k] = v
    else
      @options[keyOrHash] = value
    return

class @QuickDate
  datepicker: null
  calendarDate: null
  selectedDate: null
  scope: null
  model: null
  position:
    x: 0
    y: 0
  template: """
<div class='quickdate-popup' ng-class='{open: visible}'>
  <a href='' tabindex='-1' class='quickdate-close' ng-click='hideCalendar()'><div ng-bind-html='closeButtonHtml'></div></a>
  <div class='quickdate-text-inputs'>
    <div class='quickdate-input-wrapper'>
      <label>Date</label>
      <input class='quickdate-date-input' ng-class="{'ng-invalid': inputDateErr}" name='inputDate' type='text' ng-model='inputDate' placeholder='1/1/2013' ng-enter="selectDateFromInput(true)" ng-blur="selectDateFromInput(false)" on-tab='onDateInputTab()' />
    </div>
    <div class='quickdate-input-wrapper' ng-hide='disableTimepicker'>
      <label>Time</label>
      <input class='quickdate-time-input' ng-class="{'ng-invalid': inputTimeErr}" name='inputTime' type='text' ng-model='inputTime' placeholder='12:00 PM' ng-enter="selectDateFromInput(true)" ng-blur="selectDateFromInput(false)" on-tab='onTimeInputTab()'>
    </div>
  </div>
  <div class='quickdate-calendar-header'>
    <a href='' class='quickdate-prev-month quickdate-action-link' tabindex='-1' ng-click='prevMonth()'><div ng-bind-html='prevLinkHtml'></div></a>
    <span class='quickdate-month'>{{calendarDate | date:'MMMM yyyy'}}</span>
    <a href='' class='quickdate-next-month quickdate-action-link' ng-click='nextMonth()' tabindex='-1' ><div ng-bind-html='nextLinkHtml'></div></a>
  </div>
  <table class='quickdate-calendar'>
    <thead>
      <tr>
        <th ng-repeat='day in dayAbbreviations'>{{day}}</th>
      </tr>
    </thead>
    <tbody>
      <tr ng-repeat='week in weeks'>
        <td ng-mousedown='selectDate(day.date, true, true)' ng-click='$event.preventDefault()' ng-class='{"other-month": day.other, "disabled-date": day.disabled, "selected": day.selected, "is-today": day.today}' ng-repeat='day in week'>{{day.date | date:'d'}}</td>
      </tr>
    </tbody>
  </table>
  <div class='quickdate-popup-footer'>
    <a href='' class='quickdate-clear' tabindex='-1' ng-hide='disableClearButton' ng-click='clear()'>Clear</a>
  </div>
</div>
            """

  constructor: (@$document, @$compile, @$rootScope, @$timeout, @$sce, @$filter, @options) ->
    @initialize()

  initialize: ->
    $body = @$document.find('body')
    @scope = @initScope()
    @datepicker = angular.element(@template)
    @$compile(@datepicker) @scope
    $body.append @datepicker
    @setupEventCalls()

  initScope: ->
    scope = @$rootScope.$new()
    @setConfigOptions(scope)
    scope.weeks = [] # Nested Array of visible weeks / days in the popup
    scope.inputDate = null # Date input into the date text input field
    scope.inputTime = null # Time input into the time text input field
    scope.visible = false
    scope.invalid = true
    @setupScopeFunctions(scope)
    scope.quickDate = @
    scope

  # Copy various configuration options from the default configuration to scope
  setConfigOptions: (scope) ->
    @parseDateString = @options.parseDateFunction
    for key, value of @options
      if key.match(/[Hh]tml/)
        scope[key] = @$sce.trustAsHtml(@options[key] || "")
      else if !scope[key]
        scope[key] = @options[key]
    if !scope.labelFormat
      scope.labelFormat = scope.dateFormat
      unless scope.disableTimepicker
        scope.labelFormat += " " + scope.timeFormat

  getOption: (key)->
    @options[key]

  setupScopeFunctions: (scope)->
    quickDate = @
    scope.hideCalendar = (saveDate)->
      quickDate.close(saveDate)

    # When tab is pressed from the date input and the timepicker
    # is disabled, close the popup
    scope.onDateInputTab = ->
      if scope.disableTimepicker
        scope.hideCalendar(true)
      true

    # When tab is pressed from the time input, close the popup
    scope.onTimeInputTab = ->
      scope.hideCalendar(true)
      true

    # This is triggered when the date or time inputs have a blur or enter event.
    scope.selectDateFromInput = (closeCalendar=false) ->
      quickDate.setDateFromInput(closeCalendar)

    scope.selectDate = (date, closeCalendar=true) ->
      quickDate.selectDate(date, closeCalendar)

    # Set the date model to null
    scope.clear = ->
      scope.selectDate(null, true)

    # View the next and previous months in the calendar popup
    scope.nextMonth = ->
      quickDate.setCalendarDate(new Date(scope.calendarDate).setMonth(scope.calendarDate.getMonth() + 1))
      quickDate.refreshView()
    scope.prevMonth = ->
      quickDate.setCalendarDate(new Date(scope.calendarDate).setMonth(scope.calendarDate.getMonth() - 1))
      quickDate.refreshView()

  set: (keyOrHash, value) ->
    if typeof(keyOrHash) == 'object'
      for k, v of keyOrHash
        @options[k] = v
    else
      @options[keyOrHash] = value
    return

  open: (element, model, callback) ->
    @selectCallback = callback
    element = element[0]
    @calcPosition(element)
    @positionElement(element)
    @scope.visible = true
    @setCalendarDate(model)
    @refreshView()
    @focusOnDatePicker(@datepicker)

  refreshView: () ->
    @setupCalendarView()
    @setInputFieldValues(@selectedDate)

  close: (saveDate)->
    @scope.visible = false
    @scope.hasBeenVisible = false
    if saveDate
      @selectDate(@selectedDate)

  # Set the date that is used by the calendar to determine which month to show
  # Defaults to the current month
  setCalendarDate: (val=null) ->
    if val?
      d = new Date(val)
    else
      d = new Date()
    if (d.toString() == "Invalid Date")
      d = new Date()
    @selectedDate = new Date(d)
    d.setDate(1)
    @calendarDate = d
    @scope.calendarDate = @calendarDate
    return

  setDateFromInput: (closeCalendar)->
    try
      tmpDate = @parseDateString(@scope.inputDate)
      if !tmpDate
        throw 'Invalid Date'
      if !disableTimepicker = @getOption('disableTimepicker') && @scope.inputTime and @scope.inputTime.length and tmpDate
        tmpTime = if disableTimepicker then '00:00:00' else @scope.inputTime
        tmpDateAndTime = @parseDateString("#{@scope.inputDate} #{tmpTime}")
        if !tmpDateAndTime
          throw 'Invalid Time'
        tmpDate = tmpDateAndTime
      if !@selectDate(tmpDate, false)
        throw 'Invalid Date'

      if closeCalendar
        @close(false)

      @scope.inputDateErr = false
      @scope.inputTimeErr = false

    catch err
      if err == 'Invalid Date'
        @scope.inputDateErr = true
      else if err == 'Invalid Time'
        @scope.inputTimeErr = true

  # Select a new model date. This is called in 3 situations:
  #   * Clicking a day on the calendar or from the `selectDateFromInput`
  #   * Changing the date or time inputs, which call the `selectDateFromInput` method, which calls this method.
  #   * The clear button is clicked
  selectDate: (date, closeCalendar=true) ->
    if typeof(@scope.dateFilter) == 'function' && !@scope.dateFilter(date)
      return false
    @setCalendarDate(date)
    @setupCalendarView()
    @selectCallback(date)
    if closeCalendar
      @close(false)
    true

  focusOnDatePicker: (element)->
    dateInput = angular.element(element[0].querySelector(".quickdate-date-input"))[0]
    dateInput.select()

  getDaysInMonth: (year, month) ->
    [31, (if ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0) then 29 else 28), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month]

  # Set the values used in the 2 input fields
  setInputFieldValues: (val) ->
    if val?
      @scope.inputDate = @$filter('date')(val, @getOption('dateFormat'))
      @scope.inputTime = @$filter('date')(val, @getOption('timeFormat'))
    else
      @scope.inputDate = null
      @scope.inputTime = null

  # Setup the data needed by the table that makes up the calendar in the popup
  # Uses this.calendarDate to decide which month to show
  setupCalendarView: ->
    offset = @calendarDate.getDay()  # get day of the week
    daysInMonth = @getDaysInMonth(@calendarDate.getFullYear(), @calendarDate.getMonth())
    numRows = Math.ceil((offset + daysInMonth) / 7)
    weeks = []
    todayDate = new Date()
    defaultTime = @getOption('defaultTime')
    dateFilter = @getOption('dateFilter')
    curDate = new Date(@calendarDate)
    curDate.setDate(1 - offset)
    for row in [0..(numRows-1)]
      weeks.push([])
      for day in [0..6]
        d = new Date(curDate)
        if defaultTime
          time = defaultTime.split(':')
          d.setHours(time[0] || 0)
          d.setMinutes(time[1] || 0)
          d.setSeconds(time[2] || 0)
        selected = @selectedDate && d && @datesAreEqual(d, @selectedDate)
        today = @datesAreEqual(d, todayDate)
        weeks[row].push({
          date: d
          selected: selected
          disabled: if (typeof(dateFilter) == 'function') then !dateFilter(d) else false
          other: d.getMonth() != @calendarDate.getMonth()
          today: today
        })
        curDate.setDate(curDate.getDate() + 1)
    @scope.weeks = weeks

  datesAreEqual: (d1, d2, compareTimes=false) ->
    if compareTimes
      (d1 - d2) == 0
    else
      d1 && d2 && (d1.getYear() == d2.getYear()) && (d1.getMonth() == d2.getMonth()) && (d1.getDate() == d2.getDate())

  calcPosition: (element) ->
    xPosition = 0
    yPosition = 0
    elementHeight = element.offsetHeight
    while element
      xPosition += (element.offsetLeft - element.scrollLeft + element.clientLeft)
      yPosition += (element.offsetTop - element.scrollTop + element.clientTop)
      element = element.offsetParent
    yPosition += elementHeight
    @position.x = xPosition
    @position.y = yPosition
    return

  positionElement: () ->
    @datepicker.css("top", @position.y + 'px')
    @datepicker.css("left", @position.x + 'px')

  setupEventCalls: ->
    # This code listens for clicks both on the entire document and the popup.
    # If a click on the document is received but not on the popup, the popup
    # should be closed
    datePicker = @
    datepickerClicked = false
    window.document.addEventListener 'click', (event) ->
      if datePicker.scope.visible && ! datepickerClicked
        if datePicker.scope.hasBeenVisible
          datePicker.close()
        else
          datePicker.scope.hasBeenVisible = true
      datepickerClicked = false

    angular.element(@datepicker[0])[0].addEventListener 'click', (event) ->
      datepickerClicked = true



#===============================  Directive =================================

app.directive "ngQuickDate", ['ngQuickDate', '$filter', '$sce', (ngQuickDate, $filter, $sce) ->
  restrict: "E"
  require: "?ngModel"
  scope:
    ngModel: "="
    dateFilter: '=?'
    onChange: "&"
    required: '@'
  template: """
    <div class='quickdate'>
      <a href='' ng-focus='showCalendar()' ng-click='showCalendar()' class='quickdate-button' title='{{hoverText}}'><div ng-hide='iconClass' ng-bind-html='buttonIconHtml'></div>{{mainButtonStr()}}</a>
    </div>
  """
  replace: true
  link: (scope, element, attrs, ngModelCtrl) ->
    # INITIALIZE VARIABLES AND CONFIGURATION
    # ================================
    initialize = ->
      if attrs.placeholder && attrs.placeholder.length
        scope.placeholder = attrs.placeholder
      else
        scope.placeholder = ngQuickDate.getOption('placeholder')
      if attrs.dateFilter && attrs.dateFilter.length
        scope.dateFilter = attrs.dateFilter
      else
        scope.dateFilter = ngQuickDate.getOption('dateFilter')
      if attrs.labelFormat && attrs.labelFormat.length
        scope.labelFormat = attrs.labelFormat
      else
        scope.labelFormat = ngQuickDate.getOption('labelFormat')
      if attrs.hoverText && attrs.hoverText.length
        scope.hoverText = attrs.hoverText
      else
        scope.hoverText = ngQuickDate.getOption('hoverText')
      if attrs.iconClass && attrs.iconClass.length
        scope.buttonIconHtml = $sce.trustAsHtml("<i ng-show='iconClass' class='#{attrs.iconClass}'></i>")
      else
        scope.buttonIconHtml = ngQuickDate.getOption('buttonIconHtml')
      scope.parseDateFunction = ngQuickDate.getOption('parseDateFunction')

      if typeof(attrs.initValue) == 'string'
        ngModelCtrl.$setViewValue(attrs.initValue)
      setDate(ngModelCtrl.$modelValue)

    scope.showCalendar = ->
      ngQuickDate.open(element, scope.date, dateSelected) ##### Maybe send callback here????

#     getButtonText = ->
#       if scope.date then $filter('date')(scope.date, scope.labelFormat) else scope.placeholder


    scope.mainButtonStr = ->
      date = if ngModelCtrl.$modelValue then new Date(ngModelCtrl.$modelValue) else null
      if date then $filter('date')(date, scope.labelFormat) else scope.placeholder
      
    dateSelected = (date)->
      if typeof(scope.dateFilter) == 'function' && !scope.dateFilter(date)
        return false
      ngModelCtrl.$setViewValue(date)
      setDate(date)

    setDate = (val=null) ->
      scope.date = if val? then new Date(val) else new Date()
      if (scope.date.toString() == "Invalid Date")
        scope.date = null
      #scope.mainButtonStr = getButtonText()
      scope.invalid = ngModelCtrl.$invalid
      true
      
    # PARSERS AND FORMATTERS
    # =================================
    # When the model is set from within the datepicker, this will be run
    # before passing it to the model.
    ngModelCtrl.$parsers.push((viewVal) ->
      if scope.required && !viewVal?
        ngModelCtrl.$setValidity('required', false);
        null
      else if angular.isDate(viewVal)
        ngModelCtrl.$setValidity('required', true);
        viewVal
      else if angular.isString(viewVal)
        ngModelCtrl.$setValidity('required', true);
        scope.parseDateFunction(viewVal)
      else
        null
    )

    # When the model is set from outside the datepicker, this will be run
    # before passing it to the datepicker
    ngModelCtrl.$formatters.push((modelVal) ->
      if angular.isDate(modelVal)
        modelVal
      else if angular.isString(modelVal)
        scope.parseDateFunction(modelVal)
      else
        undefined
    )

    # Called when the model is updated from outside the datepicker
    ngModelCtrl.$render = ->
      setDate(ngModelCtrl.$viewValue)

    # Called when the model is updated from inside the datepicker,
    # either by clicking a calendar date, setting an input, etc
    ngModelCtrl.$viewChangeListeners.unshift ->
      setDate(ngModelCtrl.$viewValue)
    #      if scope.onChange
    #        scope.onChange()

    scope.$watch('ngModel', (newVal, oldVal) ->
      setDate(newVal)
    )

    initialize()

]

app.directive 'ngEnter', ->
  (scope, element, attr) ->
    element.bind 'keydown keypress', (e) ->
      if (e.which == 13)
        scope.$apply(attr.ngEnter)
        e.preventDefault()

app.directive 'onTab', ->
  restrict: 'A',
  link: (scope, element, attr) ->
    element.bind 'keydown keypress', (e) ->
      if (e.which == 9) && !e.shiftKey
        scope.$apply(attr.onTab)