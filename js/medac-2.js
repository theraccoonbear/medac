var MEDAC = {};
var TEMPLATES = {};
var TEMPLATE_ACTIONS = {};
var INDEX = {};




$(function() {
	
	var num_rgx = new RegExp(/^\d+$/);
	
	var NAV = {
		crumbs: [],
		
		currentPath: function() {
			return document.location.hash.substring(2).split('/').reverse();
		}, // currentPath()
		
		getRelPath: function(path) {
			var cur = this.currentPath();
			var shorter = Math.min(cur.length, path.length);
			
			var new_path = [];
			var i = 0;
			
			for (i = 0; i < shorter; i++) {
				if (cur[i] != path[i]) {
					break;
				}
			}
			
			
			
			
		}, // getRelPath()
		
		goTo: function(path) {
			var $cols = $('.selectColumn');
			
			for (var i = 0; i < $cols.length - 1; i++) {
				$cols.last().remove();
			}
			
			var ctxt = this;
			
			var nextNode = function() {
				if (path.length > 0 && path[0].length > 0) {
					var node_key = path.pop();
					ctxt.forward({key: node_key, speed: 0, callback: function() { if (path.length > 0) { nextNode(); } }});
				}
			};
				
			
			nextNode();
			
			
		}, // goTo();
		
		init: function() {
			var path = this.currentPath();
			this.goTo(path);	
		}, // init()
		
		updateLocation: function() {
			document.location.hash = '#!' + this.crumbs.join('/');
		}, // updateLocation()
		
		back: function(o) {
			if (typeof o === 'undefined') { o = {}; }
			var speed = typeof o.speed === 'undefined' ? 250 : o.speed;
			if (speed < 1) { speed = 1; }
			
			var $list = $('.selectColumn').last();
			NAV.crumbs.pop();
			this.updateLocation();
			
			$iface.animate({'left':'+=' + frame_width}, speed, null, function() { $list.remove(); });
		}, // back()
		
		forward: function(o) {
			if (typeof o === 'undefined') { o = {}; }
			var key = o.key;
			var speed = typeof o.speed === 'undefined' ? 250 : o.speed;
			
			if (speed < 1) { speed = 1; }
			
			NAV.crumbs.push(key);
			NAV.updateLocation();
			
			var node_action = getActionFor(NAV.crumbs);
			
			var newNode = drill(MEDAC.media, NAV.crumbs);
			var node = new colNode(newNode, key)
			
			var rendered = Mustache.render(getTemplateFor(NAV.crumbs), node);
			
			node_action(node, 'before', newNode);
			$iface.append(rendered).animate({'left': '-=' + frame_width}, speed, null, function() {
				node_action(node, 'after', newNode);
				if (typeof o.callback === 'function') {
					o.callback();
				}
			});
			
			doResize();
		} // forward()
	}; // NAV
	
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
	
	var getActionFor = function(path) {
		if (path.length < 1) { return ''; }
		var cat = path[0];
		var extent = path.length > 1 ? path.length - 1 : 0;
		var ret_val = function() { /* ... */ }
		
		if (typeof TEMPLATE_ACTIONS[cat] !== 'undefined' && typeof TEMPLATE_ACTIONS[cat][extent] !== 'undefined') {
			ret_val = TEMPLATE_ACTIONS[cat][extent];
		}
		
		return ret_val;
	}; // getActionFor()
	
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
		
		for (var cat in TEMPLATE_ACTIONS) {
			if (TEMPLATE_ACTIONS.hasOwnProperty(cat)) {
				for (var i = 0; i < TEMPLATE_ACTIONS[cat].length; i++) {
					var tmplFunc = TEMPLATE_ACTIONS[cat][i];
					if (typeof tmplFunc === 'function') {
						TEMPLATE_ACTIONS[cat][i] = tmplFunc;
					} else {
						TEMPLATE_ACTIONS[cat][i] = function() { /* ... */ };
					}
				}
			}
		}
		
		TEMPLATES._DEFAULT = DEFAULT;
	}; // loadTemplates()
	
	var rootTmpl = $('#tmpl-ROOT').html();
	//var crumbs = [];
	
	
	TEMPLATES = {
		'TV': ['BASE','SHOW','SEASON','EPISODE'],
		'Settings': ['LIST','PAGE']
	};
	
	TEMPLATE_ACTIONS = {
		'TV': [null, null, null, function(obj, when, orig) {
			if (when == 'after') {
				API.call({
					model: 'Download',
					action: 'status',
					data: {
						'resource': {
							'md5': orig.md5,
							'path': orig.rel_path,
							'size': orig.size
						}
					},
					callback: function(d, s, x) {
						//console.log("Success!");
						//console.log(d);
						if (d.payload.exists) {
							var per = Math.floor(d.payload.size / orig.size * 1000) / 10;
							$('.status .downloaded').html(per + '%');
						} else {
							$('.status .downloaded').html("Not queued");
						}
					}
				});
			}
		}],
		'Settings': [null, function(obj, when, orig) {
			if (when == 'after') {
				var $ca = $('.contentArea');
				if (obj.title == 'Download Queue') {
					API.call({
						model: 'Download',
						action: 'queue-status',
						data: {},
						callback: function(d, s, x) {
							
							if (d.success) {
								var qeTmpl = $('#tmpl-Settings-QueueEntry').html();
								for (var i = 0; i < d.payload.length; i++) {
									var f = d.payload[i];
									
									f.percent = Math.floor(f.downloaded / f.size * 1000) / 10;
									f.file = drill(MEDAC, INDEX[f.md5]);
									$ca.append(Mustache.render(qeTmpl, f));
								}
							}
						}
					});
				} else if (obj.title == 'Provider Info') {
					$('.liveSpinner').remove();
					var piTmpl = $('#tmpl-Settings-ProviderInfo').html();
					$ca.append(Mustache.render(piTmpl, MEDAC.provider));
				}
			}
		}]
	};
	
	
	
	loadTemplates();
	

	var $frame = $('#iface-frame');
	var frame_width = screen.width;
	var frame_height = screen.height;
	var $iface = $('#iface-tray');
	doResize();
	
	// UI Binding
	
	$.getJSON('media/media.json', {}, function(data, status, xhr) {
		$('#spinner').remove();
		MEDAC = data;
		MEDAC.media.Settings = {
			'Download Queue': {},
			'Provider Info': {}
		};
		buildFileIndex(MEDAC);
		
		
		//document.location.hash = '';
		//console.log(MEDAC);
		$iface.append(Mustache.render(rootTmpl, new colNode(MEDAC.media, 'Medac: ' + MEDAC.provider.name, true)));
		
		NAV.init();
	}); // get media JSON
	
	$('.selectColumn > li.menuItem > a').live('click', function(e) {
		var $this = $(this).parent('li');
		var key = $this.data('key');
		
		NAV.forward({'key':key});
		
		e.preventDefault();
		return false;
	}); // $('.selectColumn > li > a').live('click' ...
	
	$('a.goBack').live('click', function(e) {	
		NAV.back();
		e.preventDefault();
		return false;
	}); // $('a.goBack').live('click' ...
	
	$('a.dequeue').live('click', function(e) {
		var $this = $(this);
		var md5 = $this.data('md5');
		
		var file = drill(MEDAC, INDEX[md5]);
		
		API.call({
			model: 'Download',
			action: 'dequeue',
			data: {
				resource: {
					md5: file.md5
				}
			},
			callback: function(d, s, x) {
				console.log(d);
			}
		});
		
		e.preventDefault();
		return false;
	});
	
	
	// Downloads
	$('a.fileLink').live('click', function(e) {
		var $this = $(this);
		var md5 = $this.data('md5');
		
		var file = drill(MEDAC, INDEX[md5]);
		
		API.call({
			model: 'Download',
			action: 'enqueue',
			data: {
				'resource': {
					'md5': md5,
					'path': file.rel_path,
					'size': file.size
				}
			},
			callBack: function(data, status, xhr) {
				console.log("Success!");
				console.log(data);
			}
		});
		
		
		e.preventDefault();
		return false;
	});
	
	$(window).resize(doResize);
	
});