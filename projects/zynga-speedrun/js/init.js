

var Benchmark;
$(document).ready(function() {

	// initialize benchmark
	Benchmark = new z.Benchmark();

	Benchmark.parseHash();

	// track performance statistics
	var stats = {
		fps: $('#ui-stats-fps')[0],
		pps: $('#ui-stats-pps')[0],
		paints: $('#ui-stats-paints')[0]
	};

	window.setInterval(function() {
		stats.fps.innerHTML = Benchmark.statistics.fps; // || Infinity;
		stats.pps.innerHTML = Benchmark.statistics.pps; // || Infinity;
		stats.paints.innerHTML = Benchmark.statistics.paints || 0;
	}, 100);


});



