# Wraith

Wraith is for rool for making screen shots of websites and comparing
the screenshots

## Instuctions

To use wraith, install either via docker or ./make-acc

NOTE: You MUST be running the custom acceleration (eg: 3.4a) fork of
wraith, and not the BBC version.

 * Create a folder to work in eg: `~/site-diffs`.
 * wraith save_latest_images -l '_old'  -u $URL -d $DIR
 * make whatever changes to the site (include put on a new server or
   change hosts file / dns)
 * wraith save_latest_images -l '_new'  -u $URL -d $DIR
 * wraith compare_images --label1 '_old' --label2 '_new' -u $URL -d $DIR
 * This should put two galleries in place in the output folder

## Usage:

### Create a spider.txt file to use in all following processes

wraith spider --debug [--reset]  -u $URL -d $DIR

### Reset specific shot type remove files labeled "_old":

wraith reset_shots --debug -l '_old' -u $URL -d $DIR

### save "old" images

wraith save_latest_images [--reset] -l '_old' -u $URL -d $DIR

### save "new" images

wraith save_latest_images [--reset] -l '_new -u $URL -d $DIR

### compare "old" & "new" images

wraith compare_images --label1 '_old' --label2 '_new'  -u $URL -d $DIR

### make thumbs for it all

wraith generate_thumbnails -u $URL -d $DIR

### make galleries for this

wraith generate_gallery -u $URL -d $DIR


## Example Conf

Configuration files can be used to provide more guidance to wraith.
The wraith script accepts -c to pass the config file to each of the
commands

Minimal configuration:
```
directory: "~/projects/wordpress-scans/furniturekingdom.com"
domains:
  wordpress: "http://www.furniturekingdom.com"
before_capture: 'javascript/disable_javascript--phantom.js'
```

More complete configuration
```
num_threads: 8
browser: "phantomjs"
directory: "a-band-called-stew.com"
# (required) The domain(s) to take screenshots of.
domains:
  wordpress: "http://a-band-called-stew.com"
screen_widths:
  - 600x768
  - 1800
before_capture: 'javascript/disable_javascript--phantom.js'
fuzz: '2%'   #20%
# (optional) The maximum acceptable level of difference (in %) between two images before Wraith reports a failure. Default: 0
threshold: 5
gallery:
  template: 'slideshow_new_template'
  thumb_width:  200
  thumb_height: 200
```
