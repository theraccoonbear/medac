var API = {};

var ACCOUNT = {
	username: 'g33k',
	password: 'qwerty',
	host: {
		name: 'medac-dev.snm.com',
		port: 80,
	}
};

$(function() {
	
	
  API = {
		apiError: function(d, r) {
			var mkup = [];
			
			var width = Math.min(screen.width - 40, 600);
			var height = Math.min(screen.height - 40, 400);
			
			var debug_text = d.payload.error ? d.payload.error : d.payload.stacktrace.join("\n");
			
			mkup.push('<div class="modalWindow" style="left: 20px; height: 20px; width: ' + width + 'px; height: ' + height + 'px;">');
			mkup.push('<h1>API Error</h1>');
			mkup.push('<a href="#" class="dismiss">X</a>');
			mkup.push('<div class="source">' + r.model + '::' + r.action + '()</div>');
			mkup.push('<div class="help">' + d.message + '</div>');
			mkup.push('<div class="debug">' + debug_text + '</div>');
			mkup.push('</div>');
			
			var $err = $(mkup.join("\n"));
			console.log(d.payload.object);
			
			$('.dismiss').live('click', function(e) {
				var $this = $(this);
				var $modal = $this.parent('.modalWindow');
				$modal.fadeOut(250, function() {
					$(this).remove();
				});
				
				e.preventDefault();
				return false;
			});
			
			$('body').append($err);
			$err.fadeIn(250);
			
			
		},
		
    call: function(opts) {
			var ctxt = this;
			var inc_data = opts.data || {};
			var model = opts.model || 'default';
			var action = opts.action || 'who';
			var callback = typeof opts.callback === 'function' ? opts.callback : function() { /* ... */ };
			
			var request = {
				'provider': MEDAC.provider,
				'account': ACCOUNT
			};
			
			for (var p in inc_data) {
				if (inc_data.hasOwnProperty(p)) {
					request[p] = inc_data[p];
				}
			}
			
			//console.log(request);
			
			var requestDetails = {
				'model': model,
				'action': action
			};
	
			$.ajaxError = function(event, jqXHR, ajaxSettings, thrownError) {
				API.apiError({'payload': {'error': thrownError}}, requestDetails);
			}
			
			$.post(model + '/' + action, {'request': JSON.stringify(request)}, function(data, status, xhr) {
				//$('.liveSpinner').remove();
				
				if (data.success) {
					callback(data, status, xhr);
				} else{
					ctxt.apiError(data, requestDetails);
				}
			},'json');
    } // apiCall()
  } // API
	
	
	
	
});