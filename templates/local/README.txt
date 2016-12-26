These are tools local for Acceleration.net usage

To use wraith (after goign through all the install or using the docker
method) NOTE: You MUST be running the custom acceleration fork of
wraith, and not the BBC version.

'wraith setup' - will generate the sample configs and these tools

create a 'local/{site}.yaml' file for the site
  domains:
    wordpress: "http://{site-name.com}"
  directory: "{site-name.com}"
  gallery:
    template: 'slideshow_new_template' # Examples: 'basic_template' (default), 'slideshow_template'
    thumb_width:  200
    thumb_height: 200

'bash local/fetch_before' - will ask you for the domain to search before doign a migration.  It will store the files in a folder named old_shots.

'bash local/fetch_after' - Will run the same domain again and create a folder new_shots.  it will also create two gallery html pages and open them up in Firefox.

If you need to change the global configuration, edit the file local/wordpress.yaml, but you should not need to do so unless you want to change the number of threads, for instance.


## Usage:

### Reset specific shot type remove files labeled "latest":

wraith reset_shots --debug -l '_latest' local/wordpress.yaml

### save "old" images

wraith save_latest_images -l '_old' local/wordpress.yaml

### save "new" images

wraith save_latest_images -l '_new local/wordpress.yaml

### compare "old" & "new" images

wraith compare_latest_images --label1 '_old' --label2='_new' local/wordpress.yaml

### make thumbs for it all

wraith latest_thumbnails local/wordpress.yaml

### make galleries for this

wraith latest_gallery local/wordpress.yaml


## Example Conf

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
mode: diffs_first
```
