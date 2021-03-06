;(function($){
	$.fn.fdatetimepicker.dates['en-US'] = {
        days:        ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
        daysShort:   ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        daysMin:     ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"],
        months:      ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
        monthsShort: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
        meridiem:    ["am", "pm"],
        suffix:      ["st", "nd", "rd", "th"],
        today:       "Today",
        autoclose: true,
        format: "dd/mm/yyyy hh:ii",
        formatDate: "dd/mm/yyyy"
	};

    $.fn.fdatetimepicker.defaults = $.fn.fdatetimepicker.dates['en-US'];
}(jQuery));
