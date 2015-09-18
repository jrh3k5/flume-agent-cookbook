# Developer Notes #

## Software ##
The following software has to be installed to enable local testing:

* [VirtualBox](https://www.virtualbox.org/)
* [Vagrant](http://www.vagrantup.com/)
* [ChefDK](https://downloads.chef.io/chef-dk/)

## Running Tests ##

Run the tests with:

```
kitchen test
```

A successful test run will look something like:

```
# Running tests:

recipe::test_flume_consumer::default#test_0001_should complete deployment process without errors = 0.00 s = .
recipe::test_flume_consumer::default#test_0002_should have expected number of services running = [2014-06-14T22:43:49+00:00] DEBUG: service[flume_first_agent] supports status, running
[2014-06-14T22:43:50+00:00] DEBUG: service[flume_first_agent] is running
[2014-06-14T22:43:50+00:00] DEBUG: service[flume_second_agent] supports status, running
[2014-06-14T22:43:50+00:00] DEBUG: service[flume_second_agent] is running
0.86 s = .


Finished tests in 0.858888s, 2.3286 tests/s, 3.4929 assertions/s.

2 tests, 3 assertions, 0 failures, 0 errors, 0 skips
[2014-06-14T22:43:50+00:00] INFO: Report handlers complete
```

To establish a connection with the CentOS box created by Vagrant, run:

```
$ kitchen login
$ sudo su - root
```

When the testing is completed, clean up the box with:

```
$ kitchen destroy
```