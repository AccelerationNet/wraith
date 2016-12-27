# Wraith

Wraith is for rool for making screen shots of websites and comparing
the screenshots

## Instuctions

To use wraith (after goign through all the install or using the docker
method) NOTE: You MUST be running the custom acceleration fork of
wraith, and not the BBC version.

 * Create a folder to work in eg: `~/site-diffs`.
 * Create a `~/site-diffs/{site}.yaml` with the basic config from beloow
 * wraith save_latest_images -l '_old' -c ~/site-diffs/{site}.yaml
 * make whatever changes to the site (include put on a new server or
   change hosts file / dns)
 * wraith save_latest_images -l '_new' -c ~/site-diffs/{site}.yaml
 * wraith compare_images --label1 '_old' --label2 '_new' -c $CONFIG_FILE
 * This should put two galleries in place in the output folder

## Usage:

### Create a spider.txt file to use in all following processes

wraith spider --debug [--reset] -c local/wordpress.yaml

### Reset specific shot type remove files labeled "_old":

wraith reset_shots --debug -l '_old' -c local/wordpress.yaml

### save "old" images

wraith save_latest_images [--reset] -l '_old' -c local/wordpress.yaml

### save "new" images

wraith save_latest_images [--reset] -l '_new -c local/wordpress.yaml

### compare "old" & "new" images

wraith compare_latest_images --label1 '_old' --label2 '_new' -c local/wordpress.yaml

### make thumbs for it all

wraith generate_thumbnails -c local/wordpress.yaml

### make galleries for this

wraith generate_gallery -c local/wordpress.yaml


## Example Conf

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
