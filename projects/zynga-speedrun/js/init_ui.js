$(document).ready(function() {

	// create little tab dots and mark current visible as active
	function switchUITabs(direction) {

		// update tabs visiblity
		var curTab = $('.ui-sidebar-tab.visible').removeClass('visible');
		var nextTab = curTab[direction]('.ui-sidebar-tab');

		// add 'visible' class to make tab visible, fall back to current if no prev/next
		nextTab = (nextTab.length ? nextTab : curTab).addClass('visible');

		// update tabs index indicator
		$('#ui-sidebar-tabs > *').removeClass().eq(nextTab.index()).addClass('active');


	}

	// update the sidebar form from the defaults/hash tag
	for (var s in Benchmark.options) {
		z.updateUIFromOption(s, Benchmark.options[s]);
	}

	// set up "update" button
	$('#ui-update').click(function() {
		z.updateOptionsFromUI();
		return false;
	});

	// set up sliders
	$('.ui-slider').change(function() {
		$(this.getAttribute('data-info')).text(this.value.match(/\./) ? this.value.substr(0, 3) : this.value);
	});

	// prev/forward tabs
	$('#ui-sidebar-tabs-prev, #ui-sidebar-tabs-next').click(function() {
		switchUITabs(this.id.split('-')[3]);
	});

	var tabIndex = $('#ui-sidebar-tabs');
	$('.ui-sidebar-tab').each(function() {
		$('<li></li>').attr('data-href', '#' + this.id).addClass(this.className.match(/visible/) && 'active').appendTo(tabIndex);
	});

});
