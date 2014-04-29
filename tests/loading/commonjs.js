var loader = require("loader");

loader.onApplicationReady = function () {
    loader.checkUpdate()
    console.log("now i'm starting") ;
};

loader.onUpToDate = function () {
    console.log("I'm up to date") ;   
}