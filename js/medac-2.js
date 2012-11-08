var MEDAC = {};

var HIER = {
	'TV': ['','Season ','Episode ', false],
	'Movies': ['Title']
};

var colNode = function(obj, t, root) {
	var memberKeys = function(obj) {
		var members = [];
		for (var p in obj) {
			if (obj.hasOwnProperty(p)) {
				members.push(p);
			}
		}
		
		return members;
	};
	
	this.title = t;
	this.isRoot = root === true;
	this.items = memberKeys(obj);
};


var drill = function(o, keys) {
	for (var i = 0; i < keys.length; i++) {
		var k = keys[i];
		if (typeof o[k] !== 'undefined') {
			o = o[k];
		}
	}
	return o;
};


$(function() {
	var selColTmpl = $('#selColTmpl').html();
	var selColTVTmpl = $('#selColTVTmpl').html();
	var crumbs = [];
	
	
	$.getJSON('media/media.json', {}, function(data, status, xhr) {
		
		var $root = $('#root');
		var $frame = $('#iface-frame');
		var frame_width = $frame.width();
		var $iface = $('#iface-tray');
		
		MEDAC = data;
		
		
		var buildSelCol = function(title, items) {
			return Mustache.render(selColTmpl, t_obj);
		};
		
		$iface.append(Mustache.render(selColTmpl, new colNode(MEDAC.media, 'Media', true)));
		
		$('.selectColumn > li').live('click', function(e) {
			var $this = $(this);
			if (!$this.hasClass('heading')) {
				var key = $this.data('key');
				crumbs.push(key);
				var newNode = drill(MEDAC.media, crumbs);
				var wh = HIER[crumbs[0]];
				
				var node = new colNode(newNode, key)
				var terminal = false;
				
				if (typeof wh !== 'undefined') {
					var prepend = wh[crumbs.length - 1];
					var keyPre = wh[crumbs.length - 2];
					if (typeof keyPre != 'undefined') {
						node.title = keyPre + key;
					}
					if (typeof prepend !== 'undefined') {
						node.pre = prepend;
						terminal = prepend === false;
					}
				}
				
				console.log(terminal);
				
				
				$iface.append(Mustache.render(selColTmpl, node)).animate({'left': '-=' + frame_width}, 250);
				
			}
			e.preventDefault();
			return false;
		});
		
		$('a.goBack').live('click', function(e) {
			var $this = $(this);
			var $list = $this.parents('ul.selectColumn');
			
			crumbs.pop();
			$iface.animate({'left':'+=' + frame_width}, 250, null, function() { $list.remove(); });
			
			e.preventDefault();
			return false;
		});
		
	}); // get media JSON
});