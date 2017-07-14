function ant_native_log(msg, level) {
    if (level < 2)
        window.webkit.messageHandlers.logMessage.postMessage(msg);
}

window.onerror = function (msg, url, lineNo, columnNo) {
    ant_native_log(msg + " (" + url + ":" + lineNo + ")", 0)
}

var waiting_promise = {}

async function ant_native_click_intercept(href) {
    return new Promise(function (resolve, reject) {
        window.webkit.messageHandlers.linkIntercept.postMessage(href)
        this.waiting_promise = {resolve, reject}
    })

}

function ant_window_click_listener(e) {
    e = e || window.event;
    
    if ("ant_intercept_handled" in e)
    {
        ant_native_log("already intercepted", 3)
        return;
    }
    
    ant_native_log("interception", 3)
    
    var element = e.target || e.srcElement;
    if (element.tagName == 'A') {
        ant_native_click_intercept(element.href).then(function() {
            ant_native_log("link intercepted", 3)
            
        }, function() {
            ant_native_log("passing link through", 3)
            var clone_event = new e.constructor(e.type, e)
            clone_event.ant_intercept_handled = true
            element.dispatchEvent(clone_event)
        });
        
        e.stopImmediatePropagation();
        e.preventDefault();
        return false;
    }
}

window.addEventListener('click', ant_window_click_listener, true);
