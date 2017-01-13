module.exports = function (options) {
  var parseArgs = function(){
    var options={
      args:  system.args.slice(1),
      pos: [],
      named: {}
    };
    var key,val,next = false;
    options.args.forEach(function (arg, i){
      if(next){
        options.named[key.toLowerCase()]=arg;
      }
      else if(arg.match(/^--/)){
        var parts = arg.split('=');
        var key = parts[0].replace(/^--/,'');
        if (parts.length==1){
          next = true;
          return true;
        }
        var val = parts[1];
        if(val && val[0].match(/['"]/)) val = val.substring(1,val.length-1);
        options.named[key.toLowerCase()] = val;
      }
      else{
        options.pos.push(arg);
      }
      key = null;
      next = false;
    });
    return options;
  };
  var options = parseArgs();
  commandLineDimensions = '' + options.named.dimensions; // cast to string

  function getWidthAndHeight(dimensions) {
    dimensions = /(\d*)x?((\d*))?/i.exec(dimensions);
    return {
      'width':  parseInt(dimensions[1]),
      'height': parseInt(dimensions[2] || 1500)
    };
  }

  var multipleDimensions = commandLineDimensions.split(','),
  dimensionsToPass;

  if (multipleDimensions.length > 1) {
    dimensionsToPass = multipleDimensions.map(function (cliDimensions) {
      return getWidthAndHeight(cliDimensions);
    });
  }
  else {
    dimensionsToPass = getWidthAndHeight(commandLineDimensions);
  }

  return {
    options: options,
    dimensions: dimensionsToPass,
    takingMultipleScreenshots: function (dimensions) {
      return dimensions.length && dimensions.length > 1;
    },
    replaceImageNameWithDimensions: function (image_name, currentDimensions) {
      // shots/clickable_guide__after_click/MULTI_casperjs_english.png
      // ->
      // shots/clickable_guide__after_click/1024x359_casperjs_english.png
      var dirs = image_name.split('/'),
      filename = dirs[dirs.length - 1],
      filenameParts = filename.split('_'),
      newFilename;

      filenameParts[0] = currentDimensions.viewportWidth + 'x' + currentDimensions.viewportHeight;
      dirs.pop(); // remove MULTI_casperjs_english.png
      newFilename = dirs.join('/') + '/' + filenameParts.join('_');
      return newFilename;
    }
  };
};
