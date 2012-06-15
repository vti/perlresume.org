// Based on http://fitzgen.github.com/github-api/
// Removed everything I don't need and use GitHub API v3

(function (globals) {

    var

    apiRoot = "https://api.github.com/",

    jsonp = function (url, callback, context) {
        var id = +new Date,
        script = document.createElement("script");

        while (gh.__jsonp_callbacks[id] !== undefined)
            id += Math.random(); // Avoid slight possibility of id clashes.

        gh.__jsonp_callbacks[id] = function () {
            delete gh.__jsonp_callbacks[id];
            callback.apply(context, arguments);
        };

        var prefix = "?";
        if (url.indexOf("?") >= 0)
            prefix = "&";

        url += prefix + "callback=" + encodeURIComponent("gh.__jsonp_callbacks[" + id + "]");
        script.setAttribute("src", apiRoot + url);

        document.getElementsByTagName('head')[0].appendChild(script);
    },

    gh = globals.gh = {};

    gh.__jsonp_callbacks = {};

    gh.user = function (username) {
        if ( !(this instanceof gh.user)) {
            return new gh.user(username);
        }
        this.username = username;
    };

    gh.user.prototype.get = function (callback, context) {
        jsonp("users/" + this.username, callback, context);
        return this;
    };
}(window));
