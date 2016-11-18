These are tools local for Acceleration.net usage

To use wraith (after goign through all the install or using the docker method)  NOTE: You MUST be running the custom acceleration fork of wraith, and not the BBC version.

'wraith setup' - will generate the sample configs and these tools

'bash local/fetch_before' - will ask you for the domain to search before doign a migration.  It will store the files in a folder named old_shots.

'bash local/fetch_after' - Will run the same domain again and create a folder new_shots.  it will also create two gallery html pages and open them up in Firefox.

BUG NOTICE:

Wraith currently has a bug where the load and snap processes can hang and eventually on a large site, it will stop processing files altogether.  There is a hawk monitor script (local/phantomjs_hawk) thyat automatically runs in the background to monitor the running phantomjs processes and kill off any that take longer than 60 seconds to run.  It will retry those processes five times before giving up.

If you need to change the global configuration, edit the file local/wordpress.yaml, but you should not need to do so unless you want to change the number of threads, for instance.

