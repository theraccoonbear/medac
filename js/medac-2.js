var MEDAC = {};

$(function() {
	var selColTmpl = $('#selColTmpl').html();
	
	$.getJSON('media/media.json', {}, function(data, status, xhr) {
		
		var $root = $('#root');
		
		
		MEDAC = data;
		
		var media = data.media;
		
		var $iface = $('#iface-wrapper');
		
		var media_types = {
			name: "Media Types",
			items: []
		};
		
		for (var prop in data.media) {
			if (data.media.hasOwnProperty(prop)) {
				var item = {name: prop, key: prop};
				media_types.items.push(item);
			}
		}
		
		$iface.append(Mustache.render(selColTmpl, media_types));
		
		//renderDir($root, media);
		
		//renderTV($root, media.TV);
		
		
		
		//$('.dirLink').click(function(e) {
		//	$ctxt = $(this);
		//	$parent = $ctxt.parent('li');
		//	
		//	if ($parent.hasClass('closed')) {
		//		var eo = typeof $parent.data('opened') !== 'undefined';
		//		if (eo) {
		//			$parent.children('td.thumbs');
		//		} else {
		//			$parent.data('opened','true');
		//		}
		//		
		//		$parent.children('ul').slideDown(250);
		//		$parent.removeClass('closed');
		//	} else {
		//		$parent.children('ul').slideUp(250);
		//		$parent.addClass('closed')
		//	}
		//	
		//	//$parent.toggleClass('closed');
		//	
		//	if (e.preventDefault) { e.preventDefault(); }
		//				
		//	return false;
		//});
		//
		//$('.showThumbs').click(function(e) {
		//	var $a = $(this);
		//	$a.fadeOut(250, function() { $(this).remove(); });
		//	var $div = $a.parent('.hiddenThumbs');
		//	var $imgs = $div.find('img.thumb');
		//	
		//	var cnt = 0;
		//	var fade_time = Math.floor(1000 / $imgs.length);
		//	
		//	$imgs.each(function(idx, elem) {
		//		var $img = $(elem);
		//		
		//		$img.attr('src', $img.data('src'));
		//		setTimeout(function() {
		//			$img.fadeIn(fade_time);
		//		}, Math.floor(cnt * fade_time * 0.5));
		//		cnt++;
		//		
		//	});
		//	
		//	//$div.removeClass('hiddenThumbs');
		//	$a.remove();
		//	
		//	e.preventDefault();
		//});
		
		//$('.fileLink').click(function(e) {
		//	var $this = $(this);
		//	var md5 = $this.data('md5');
		//	
		//	if (typeof md5_cache[md5] !== 'undefined') {
		//		console.log("Cache hit for: " + md5);
		//		console.log(md5_cache[md5]);
		//	} else {
		//		console.log("No cache hit for: " + md5);
		//	}
		//});
	}); // get media JSON
});