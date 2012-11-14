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
    call: function(opts) {
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
			
			
			$.post(model + '/' + action, {'request': JSON.stringify(request)}, function(data, status, xhr) {
				$('.liveSpinner').remove();
				callback(data, status, xhr);
			},'json');
    } // apiCall()
  } // API
});