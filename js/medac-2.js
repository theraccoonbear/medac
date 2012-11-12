var MEDAC = {};
var TEMPLATES = {};
var INDEX = {};

var ACCOUNT = {
	username: 'g33k',
	password: 'qwerty',
	host: {
		name: 'medac-dev.snm.com',
		port: 80,
	}
};


$(function() {
	
	var num_rgx = new RegExp(/^\d+$/);
	
	var buildFileIndex = function(data) {
		var depth = 0;
		var crawlObj = function(obj, crumbs) {
			depth++;
			if (depth > 20) { return; }		
			if (typeof crumbs === 'undefined') {
				crumbs = [];
			}
			for (var p in obj) {
				if (obj.hasOwnProperty(p)) {
					if (p == 'md5') {
						INDEX[obj[p]] = crumbs.slice(0);
					} else {
						var deeper = false;
						if (num_rgx.test(p) && typeof obj !== 'string') {
							deeper = true;
						} else if (!num_rgx.test(p)) {
							deeper = true;
						}
						if (deeper) {
							crumbs.push(p);
							crawlObj(obj[p], crumbs);
							crumbs.pop();
						}
					}
				}
			}
			depth--;
		}; // crawlObj();
		
		crawlObj(data);
	}; // buildFileIndex()
	
	var colNode = function(obj, t, root) {
		var n = {
			title: t,
			items: [],
			orig: {}
		};
		
		var num_indexes = true;
		for (var p in obj) {
			if (obj.hasOwnProperty(p)) {
				num_indexes = num_indexes && num_rgx.test(p);
				//console.log(num_indexes + ' : ' + p);
				if (!num_indexes) { break; }
			}
		}
		
		
		for (var p in obj) {
			if (obj.hasOwnProperty(p)) {
				if (num_indexes) {
					n.items[p] = {key:p,val:obj[p]};
				} else {
					n.items.push({key:p,val:obj[p]});
				}
				n.orig[p] = obj[p];
			}
		}

		return n;
	}; // colNode()
	
	var colNodeX = function(obj, t, root) {
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
	}; // colNode()
	
	
	var drill = function(o, keys) {
		for (var i = 0; i < keys.length; i++) {
			var k = keys[i];
			if (typeof o[k] !== 'undefined') {
				o = o[k];
			}
		}
		return o;
	}; // drill()
	
	var doResize = function() {
		frame_width = screen.availWidth;
		frame_height = screen.availHeight;
		$frame.css({width: frame_width, height: frame_height});
		$('.selectColumn').css({'width':frame_width});
		$('.selectColumn > li').css({'width':frame_width - 50});
	}; // doResize()
	
	var buildSelCol = function(title, items) {
		return Mustache.render(selColTmpl, t_obj);
	}; // buildSelCol()
	
	var updateLocation = function() {
		document.location.hash = '#' + crumbs.join('/');
	}; // updateLocation()
	
	var getTemplateFor = function(path) {
		if (path.length < 1) { return ''; }
		var cat = path[0];
		var extent = path.length > 1 ? path.length - 1 : 0;
		var ret_val = TEMPLATES._DEFAULT;
		
		if (typeof TEMPLATES[cat] !== 'undefined' && typeof TEMPLATES[cat][extent] !== 'undefined') {
			ret_val = TEMPLATES[cat][extent];
		}
		
		return ret_val;
	}; // getTemplateFor()
	
	var loadTemplates = function() {
		var DEFAULT = '<DIV class="selectColumn"><a href="#" class="goBack">&laquo;</a> MISSING TEMPLATE!</div>';
		for (var cat in TEMPLATES) {
			if (TEMPLATES.hasOwnProperty(cat)) {
				for (var i = 0; i < TEMPLATES[cat].length; i++) {
					var tmplID = '#tmpl-' + cat + '-' + TEMPLATES[cat][i];
					var $tmpl = $(tmplID);
					if ($tmpl.length > 0) {
						TEMPLATES[cat][i] = $tmpl.html();
					} else {
						TEMPLATES[cat][i] = '<DIV class="selectColumn"><a href="#" class="goBack">&laquo;</a> UNDEFINED TEMPLATE "' +  cat + ':' + TEMPLATES[cat][i] + '"!</div>';
					}
				}
			}
		}
		TEMPLATES._DEFAULT = DEFAULT;
	}; // loadTemplates()
	
	$('.selectColumn > li.menuItem > a').live('click', function(e) {
		var $this = $(this).parent('li');
		var key = $this.data('key');
		
		crumbs.push(key);
		updateLocation();
		
		var newNode = drill(MEDAC.media, crumbs);
		var node = new colNode(newNode, key)
		
		console.log(node);
		
		var rendered = Mustache.render(getTemplateFor(crumbs), node);
		
		$iface.append(rendered).animate({'left': '-=' + frame_width}, 250);
		doResize();
		
		e.preventDefault();
		return false;
	}); // $('.selectColumn > li > a').live('click' ...
	
	$('a.goBack').live('click', function(e) {	
		var $a = $(this);
		var $list = $a.parents('.selectColumn');
		
		crumbs.pop();
		updateLocation();
		
		$iface.animate({'left':'+=' + frame_width}, 250, null, function() { $list.remove(); });
		
		e.preventDefault();
		return false;
	}); // $('a.goBack').live('click' ...
	
	$('a.fileLink').live('click', function(e) {
		
		
		e.preventDefault();
		return false;
	});
	
	
	
	$(window).resize(doResize);
	
	var rootTmpl = $('#tmpl-ROOT').html();
	var crumbs = [];
	
	
	TEMPLATES = {
		'TV': ['BASE','SHOW','SEASON','EPISODE']
	};
	
	loadTemplates();
	

	var $frame = $('#iface-frame');
	var frame_width = screen.width;
	var frame_height = screen.height;
	var $iface = $('#iface-tray');
	doResize();
	
	
	$.getJSON('media/media.json', {}, function(data, status, xhr) {
		$('#spinner').remove();
		MEDAC = data;
		buildFileIndex(MEDAC);
		console.log(MEDAC);
		$iface.append(Mustache.render(rootTmpl, new colNode(MEDAC.media, 'Media', true)));		
	}); // get media JSON
	
	
	// Downloads
	$('a.fileLink').live('click', function(e) {
		var $this = $(this);
		var md5 = $this.data('md5');
		
		var file = drill(MEDAC, INDEX[md5]);
		
		var request = {
			'provider': MEDAC.provider,
			'account': ACCOUNT,
			'resource': {
				'md5': md5,
				'path': file.rel_path,
				'size': file.size
			}
		}
		
		//console.log(request);
		
		//$.post('/cgi-bin/start-download.cgi', {'request': JSON.stringify(request)}, function(data, status, xhr) {
		$.post('/download/enqueue', {'request': JSON.stringify(request)}, function(data, status, xhr) {
			console.log(data);
		},'json');
		
		
		e.preventDefault();
		return false;
	});
	
	
});