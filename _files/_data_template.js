$(document).ready(function(){
	$.ajax({
		url: "https://gentooqa.levelnine.at/api/get_data.php",
		method: "GET",
		data: {
			mget: "(select date(sTimeStamp) as sTimeStamp, DATABASEVALUE from DATABASENAME order by sTimeStamp desc limit 40) order by sTimeStamp ASC",
			mdb: "DATABASE"
		},
		cache: false,
		success: function(data) {
			console.log(data);

			var score = {
				v00 : [],
			};

			var label = []
			var len = data.length;

			for (var i = 0; i < len; i++) {
				score.v00.push(data[i].DATABASEVALUE);
				label.push(data[i].sTimeStamp);
			}

			var ctx = $("#CANVASID");

			var data = {
				labels: label,
				datasets: [
					{
						label : "LABEL",
						data : score.v00,
						backgroundColor : "#6E56AF",
						borderColor : "#DDDFFF",
						fill : false,
						lineTension : 0,
						pointRadius : 3
					}
				]
			};

			var options = {
				title: {
					display : false,
					position : "top",
					text : "TITLE",
					fontSize : 18,
					fontColor : "#111"
				},
				legend: {
					display : false,
					position : "bottom"
				}
			};

			var chart = new Chart(ctx, {
				type : "line",
				data : data,
				options : options
			});
		},

		error: function(data) {
			console.log(data);
		}
	});
});
