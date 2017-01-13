// modules

var system = require('system'),
    page   = require('webpage').create();
var helper = require('./_helper.js')(options);
var DEBUG = false;

console.debug = function () {
  if(DEBUG) console.info.apply(console, arguments);
};

console.info = function () {
    var d = new Date();
  var args = [];
  for(var i=0,v ; i<arguments.length ; i++){
    v=arguments[i];
    if(typeof(v) == 'object') v = JSON.stringify(v).replace(/([,\}\{])/gi,"$1\n");
    args.push(v);
  };
  system.stderr.write(d.toISOString()+" - ");
  system.stderr.write(Array.prototype.join.call(args, ' ') + '\n');
}
console.error = console.info;

var options = helper.options.named;
// command line arguments
console.info('Running image capture: ', options);
var dimensions = helper.dimensions,
    image_name = options.output,
    selector   = options.selector,
    globalBeforeCaptureJS = options.global_before_capture,
    pathBeforeCaptureJS = options.path_before_capture,
    dimensionsProcessed = 0,
    currentDimensions;

globalBeforeCaptureJS = globalBeforeCaptureJS === 'false' ? false : globalBeforeCaptureJS;
pathBeforeCaptureJS   = pathBeforeCaptureJS === 'false' ? false : pathBeforeCaptureJS;

var current_requests = 0;
var last_request_timeout;
var final_timeout;

var setupJavaScriptRan = false;

var waitTime = 300, delay= 5000,
    maxWait = 5000,
    beenLoadingFor = 0;

if (helper.takingMultipleScreenshots(dimensions)) {
  currentDimensions = dimensions[0];
  image_name = helper.replaceImageNameWithDimensions(image_name, currentDimensions);
}
else {
  currentDimensions = dimensions;
}

page.settings = { loadImages: true, javascriptEnabled: true};
page.settings.userAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/28.0.1500.95 Safari/537.17';

/*
page.onError = function(msg, trace) {
  console.error('ERROR: ', msg, trace);
};
*/

var setDimensions = function(){
  page.viewportSize = currentDimensions;
  page.evaluate(function (w,h) {
        window.screen = {
          width: w,
          height: h
        };
  }, currentDimensions.width, currentDimensions.height);
  page.clipRect = {
    top: 0,
    left: 0,
    height: currentDimensions.height,
    width: currentDimensions.width
  };
};

page.onInitialized = function () {
  setDimensions();
};

page.onResourceRequested = function(req, networkRequest) {
  current_requests += 1;
  // manually change the ip address, so we can request dev domains to see if
  // they are ready to be live
  options.domain = options.url.replace(/https?:\/\//, '').split('/')[0];
  var match = req.url.match('https?://'+options.domain);
  var matchip = req.url.match('https?://'+options.ip);
  if(match){
    if(!options.ip){
      console.debug('------\nRequesting Page ('+current_requests+'): ', req.url);
    }
    else{
      newurl = req.url.replace(options.domain, options.ip);
      console.debug('------\nRequesting Page ('+current_requests+'): ',
                    req.url, '\nnewurl', newurl,'\n--------------');
      networkRequest.setHeader('Host', options.domain);
      networkRequest.changeUrl(newurl);
    }
  }
  else if(matchip){
    networkRequest.setHeader('Host', options.domain);
    console.debug('------\nRequesting Page ('+current_requests+'): ', req.url);
  }
};

page.onResourceError = function(resourceError) {
  console.error('Unable to load resource (#' , resourceError.id + 'URL:' , resourceError.url + ')');
  console.error('Error code: ', resourceError.errorCode + '. Description: ' , resourceError.errorString);
};

page.onResourceReceived = function(res) {
  if (res.stage === 'end') {
    // console.error('Resource Recieved ('+current_requests+'): ', page.viewportSize);
    current_requests -= 1;
  }
};

console.info('Loading ' + options.url , ' at dimensions: ' , currentDimensions);

page.open(options.url, function(status) {
  if (status !== 'success') {
    console.error('Error with page ' + options.url);
    phantom.exit();
  }
  setTimeout(checkStatusOfAssets, waitTime);
});


function checkStatusOfAssets() {
  if (current_requests >= 1) {
    if (beenLoadingFor > maxWait) {
      // sometimes not all assets will download in an acceptable
      // time - continue anyway.
      markPageAsLoaded();
    }
    else {
      beenLoadingFor += waitTime;
      setTimeout(checkStatusOfAssets, waitTime);
    }
  }
  else {
    markPageAsLoaded();
  }
}

function markPageAsLoaded() {
  if (!setupJavaScriptRan) {
    runSetupJavaScriptThen(captureImage);
  }
  else {
    captureImage();
  }
}


function runSetupJavaScriptThen(callback) {
  setupJavaScriptRan = true;
  if (globalBeforeCaptureJS && pathBeforeCaptureJS) {
    require(globalBeforeCaptureJS)(page, function thenExecuteOtherBeforeCaptureFile() {
      require(pathBeforeCaptureJS)(page, callback);
    });
  }
  else if (globalBeforeCaptureJS) {
    require(globalBeforeCaptureJS)(page, callback);
  }
  else if (pathBeforeCaptureJS) {
    require(pathBeforeCaptureJS)(page, callback);
  }
  else {
    callback();
  }
}

function captureImage() {
  takeScreenshot();
  dimensionsProcessed++;
  if (helper.takingMultipleScreenshots(dimensions) && dimensionsProcessed < dimensions.length) {
    currentDimensions = dimensions[dimensionsProcessed];
    image_name = helper.replaceImageNameWithDimensions(image_name, currentDimensions);
    setTimeout(resizeAndCaptureImage, waitTime);
  }
  else {
    exit_phantom();
  }
}

function resizeAndCaptureImage() {
  console.info('Resizing ', options.url, ' to: ', currentDimensions);
  page.viewportSize = currentDimensions;
  setTimeout(captureImage, delay); // give page time to re-render properly
}

function takeScreenshot() {
  console.info('Snapping ', options.url, ' at: ', currentDimensions);
  setDimensions();
  page.render(image_name);
}

function exit_phantom() {
  // prevent CI from failing from 'Unsafe JavaScript attempt to access frame with URL about:blank from frame with URL' errors. See https://github.com/n1k0/casperjs/issues/1068
  setTimeout(function(){
    phantom.exit();
  }, 30);
}
