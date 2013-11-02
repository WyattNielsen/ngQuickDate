"use strict"

describe "ngQuickDate", ->
  beforeEach angular.mock.module("ngQuickDate")
  describe "datepicker", ->
    element = undefined
    scope = undefined
    describe 'Given a datepicker element with a placeholder', ->
      beforeEach angular.mock.inject(($compile, $rootScope) ->
        scope = $rootScope
        element = $compile("<datepicker placeholder='Choose a Date' ng-model='myDate' />")(scope)
      )

      it 'Should show the proper text in the button based on the value of the ng-model', ->
        scope.myDate = null
        scope.$digest()
        button = angular.element(element[0].querySelector(".ng-quick-date-button"))
        expect(button.text()).toEqual "Choose a Date"

        scope.myDate = ""
        scope.$digest()
        expect(button.text()).toEqual "Choose a Date"

        scope.myDate = new Date(2013, 9, 25)
        scope.$digest()
        expect(button.text()).toEqual "10/25/2013"

      it 'Should show the proper value in the date input based on the value of the ng-model', ->
        scope.myDate = null
        scope.$digest()
        dateTextInput = angular.element(element[0].querySelector(".ng-qd-date-input"))
        expect(dateTextInput.val()).toEqual ""

        scope.myDate = ""
        scope.$digest()
        expect(dateTextInput.val()).toEqual ""

        scope.myDate = new Date(2013, 9, 25)
        scope.$digest()
        expect(dateTextInput.val()).toEqual "10/25/2013"

    describe 'Given a basic datepicker', ->
      beforeEach angular.mock.inject(($compile, $rootScope) ->
        scope = $rootScope
        scope.myDate = new Date(2013, 8, 1) # September 1 (months are 0-indexed)
        element = $compile("<datepicker ng-model='myDate' />")(scope)
        scope.$digest()
      )

      it 'Should let me set the date from the calendar', ->
        element.scope().setDate(Date.parse('10/05/2013')) # click on TD for this date
        scope.$apply()
        expect(scope.myDate.getDate()).toEqual(5)

      # TODO
      describe 'After typing a valid date into the date input field', ->
        beforeEach ->
          textInput = angular.element(element[0].querySelector(".ng-qd-date-input"))
          textInput.val('11/15/2013')
          browserTrigger(textInput, 'input')

        it 'should not change the ngModel just yet', ->
          expect(element.scope().ngModel).toEqual(Date.parse('09/1/2013'))

        describe 'and leaving the field (blur event)', ->
          beforeEach ->
            textInput = angular.element(element[0].querySelector(".ng-qd-date-input"))
            browserTrigger(textInput, 'blur')

          it 'should change ngModel', ->
            expect(element.scope().ngModel).toEqual(Date.parse('11/15/2013'))

          it 'should change the calendar to the proper month', ->
            $monthSpan = $(element).find(".ng-quick-date-month")
            expect($monthSpan.html()).toEqual('November 2013')

          it 'should highlight the selected date', ->
            selectedTd = $(element).find('.selected')
            expect(selectedTd.text()).toEqual('15')

        describe 'and types Enter', ->
          beforeEach ->
            console.log 'Triggering enter'
            $(element).find('.ng-qd-date-input').trigger($.Event('keypress', { which: 13 }));
         
          it 'should change ngModel', ->
            expect(element.scope().ngModel).toEqual(Date.parse('11/15/2013'))

      # TODO
      xdescribe 'After typing an invalid date into the date input field', ->
        it 'should add an error class to the input'
        it 'should not change the ngModel'
        it 'should not change the calendar month'

    describe 'Given a datepicker set to August 1, 2013', ->
      beforeEach angular.mock.inject(($compile, $rootScope) ->
        scope = $rootScope
        scope.myDate = new Date(2013, 7, 1) # August 1 (months are 0-indexed)
        element = $compile("<datepicker placeholder='Choose a Date' ng-model='myDate' />")(scope)
        scope.$digest()
      )

      it 'Should show the proper text in the button based on the value of the ng-model', ->
        $monthSpan = $(element).find(".ng-quick-date-month")
        expect($monthSpan.html()).toEqual('August 2013')

      it 'Should have last-month classes on the first 4 boxes in the calendar (because the 1st is a Thursday)', ->
        firstRow = angular.element(element[0].querySelector(".ng-quick-date-calendar .week"))
        for i in [0..3]
          box = angular.element(firstRow.children()[i])
          expect(box.hasClass('other-month')).toEqual(true)

        expect(angular.element(firstRow.children()[4]).text()).toEqual '1'

      it "Should add a 'selected' class to the Aug 1 box", ->
        $fifthBoxOfFirstRow = $(element).find(".ng-quick-date-calendar tr.week:nth-child(1) td.day:nth-child(5)")
        expect($fifthBoxOfFirstRow.hasClass('selected')).toEqual(true)

      describe 'And I click the Next Month button', ->
        beforeEach ->
          nextButton = $(element).find('.ng-quick-date-next-month')
          browserTrigger(nextButton, 'click');
          scope.$apply()

        it 'Should show September', ->
          $monthSpan = $(element).find(".ng-quick-date-month")
          expect($monthSpan.html()).toEqual('September 2013')

        it 'Should show the 1st on the first Sunday', ->
          expect(angular.element(element[0].querySelector(".ng-quick-date-calendar .day")).text()).toEqual '1'

      it 'should show the proper number of rows in the calendar', ->
        scope.myDate = Date.parse('6/1/2013')
        scope.$digest()
        expect($(element).find('.ng-quick-date-calendar .week').length).toEqual(6)
        scope.myDate = Date.parse('11/1/2013')
        scope.$digest()
        expect($(element).find('.ng-quick-date-calendar .week').length).toEqual(5)
        scope.myDate = Date.parse('2/1/2015')
        scope.$digest()
        expect($(element).find('.ng-quick-date-calendar .week').length).toEqual(4)

    describe 'Given a datepicker set to today', ->
      beforeEach angular.mock.inject(($compile, $rootScope) ->
        scope = $rootScope
        scope.myDate = new Date()
        element = $compile("<datepicker placeholder='Choose a Date' ng-model='myDate' />")(scope)
        scope.$apply()
      )

      it "Should add a 'today' class to the today td", ->
        expect($(element).find('.today').length).toEqual(1)
        nextButton = $(element).find('.ng-quick-date-next-month')
        browserTrigger(nextButton, 'click')
        browserTrigger(nextButton, 'click') # 2 months later, since today's date could still be shown next month
        scope.$apply()
        expect($(element).find('.today').length).toEqual(0)

