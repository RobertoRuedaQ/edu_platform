module Schedules
  # "Mi horario" — teacher/homeroom see their own group's slots. Apéndice A
  # also lists student(portal) as a consumer; the student portal isn't wired
  # to this yet (it's a separate, un-navved surface) — TODO when that lands.
  class MyScheduleController < ApplicationController
    def show
      authorize!("schedule.view")
      @events = Schedules::ScheduleScope.new(context: authorization_context).resolve
    end
  end
end
