var __media = {};
var __local = {};
var __md5_cache = {};

$(function() {
	var countFields = function(obj) {
		var cnt = 0;
		for (var p in obj) {
			if (obj.hasOwnProperty(p)) {
				cnt++;
			}
		}
		return cnt;
	};
	
	var firstField = function(obj) {
		for (var p in obj) {
			if (obj.hasOwnProperty(p)) {
				return p;
			}
		}
		return false;
	};
	
	
	
	var tmplDir = $('#tmplDirEntry').html();
	var tmplVid = $('#tmplVideoEntry').html();
	var tmplThumbs = $('#tmplThumbs').html();
	var tmplNode = $('#tmplNodeEntry').html();
	var tmplContent = $('#tmplContentEntry').html();
	
	var formatFileSize = function(size) {
		
	}; // formatFileSize()
	
	var renderFile = function($attach_to, file_node) {
		//console.log("FILE: " + file_node.name);
		if (typeof file_node.meta !== 'undefined' && typeof file_node.meta.length !== 'undefined' && file_node.meta.length > 5 * 60) {
			__md5_cache[file_node.md5] = file_node;
			var $file = $(Mustache.render(tmplVid, file_node));
			$file.find('td.thumb').html(Mustache.render(tmplThumbs, file_node));
			$attach_to.append($file);
		}
	}; // renderFile();
	
	var renderEpisode = function($attach_to, episodes, episode_number) {
		var episode = episodes[episode_number];
		
		renderFile($attach_to, episode);
	}; // renderEpisode()
	
	var renderSeason = function($attach_to, seasons, season_number) {
		var season = seasons[season_number];
		var $season = $(Mustache.render(tmplNode, 'Season ' + season_number));
		$attach_to.append($season);
		var $children = $season.find('ul.children');
		for (var episode_number in season) {
			if (season.hasOwnProperty(episode_number)) {
				renderEpisode($children, season, episode_number);
			}
		}
	}; // renderSeason)
	
	var renderShow = function($attach_to, shows, show_name) {
		var show = shows[show_name];
		var $show = $(Mustache.render(tmplNode, show_name));
		$attach_to.append($show);
		var $children = $show.find('ul.children');
		
		var season_num = firstField(show);
		
		if (countFields(show) == 1 && !/^\d+$/.test(season_num)) {
			if (season_num !== false) {
				var episodes = show[season_num];
				for (var ep_num in episodes) {
					renderEpisode($children, episodes, ep_num);
				}
			}
		} else {
			for (var season_number in show) {
				if (show.hasOwnProperty(season_number)) {
					renderSeason($children, show, season_number);
				}
			}
		}
	}; // renderShow()
	
	var renderTV = function($attach_to, node) {
		var $tv = $(Mustache.render(tmplContent, 'TV'));
		
		$attach_to.append($tv);
		var $children = $tv.find('ul.children');
		
		var or_arr = [];
		
		for (var show_name in node) {
			if (node.hasOwnProperty(show_name)) {
				or_arr.push(show_name);
			}
		}
		
		or_arr.sort();
		
		for (var i = 0; i < or_arr.length; i++) {
			var show_name = or_arr[i];
			renderShow($children, node, show_name);
		}
		
	}; // renderTV()
	
	$.getJSON('media/media.json', {}, function(data, status, xhr) {
		
		var $root = $('#root');
		
		
		__media = data;
		console.log(data);
		
		
		
		var media = data.media;
		
		//renderDir($root, media);
		
		renderTV($root, media.TV);
		
		$('.dirLink').click(function(e) {
			$ctxt = $(this);
			$parent = $ctxt.parent('li');
			
			if ($parent.hasClass('closed')) {
				var eo = typeof $parent.data('opened') !== 'undefined';
				if (eo) {
					$parent.children('td.thumbs');
				} else {
					$parent.data('opened','true');
				}
				
				$parent.children('ul').slideDown(250);
				$parent.removeClass('closed');
			} else {
				$parent.children('ul').slideUp(250);
				$parent.addClass('closed')
			}
			
			//$parent.toggleClass('closed');
			
			if (e.preventDefault) { e.preventDefault(); }
						
			return false;
		});
		
		$('.showThumbs').click(function(e) {
			var $a = $(this);
			$a.fadeOut(250, function() { $(this).remove(); });
			var $div = $a.parent('.hiddenThumbs');
			var $imgs = $div.find('img.thumb');
			
			var cnt = 0;
			var fade_time = Math.floor(1000 / $imgs.length);
			
			$imgs.each(function(idx, elem) {
				var $img = $(elem);
				
				$img.attr('src', $img.data('src'));
				setTimeout(function() {
					$img.fadeIn(fade_time);
				}, Math.floor(cnt * fade_time * 0.5));
				cnt++;
				
			});
			
			//$div.removeClass('hiddenThumbs');
			$a.remove();
			
			e.preventDefault();
		});
		
		$('.fileLink').click(function(e) {
			var $this = $(this);
			var md5 = $this.data('md5');
			
			if (typeof __md5_cache[md5] !== 'undefined') {
				console.log("Cache hit for: " + md5);
				//console.log(__md5_cache[md5]);
				__local.enqueueDownload(md5);
			} else {
				console.log("No cache hit for: " + md5);
			}
		});
	});
	
		
	__local = {
		enqueueDownload: function(md5) {
			var item = __md5_cache[md5];
			console.log(item);
		}
	};
	
});