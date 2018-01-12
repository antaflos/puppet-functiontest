## Overview

This module, named `functiontest`, constructs a simple test case to prove
Puppet environment isolation problems when using a parser function that calls a
custom utility method.

The problem, in a nutshell, is that if this module is available in multiple
Puppet environments then the Puppet master will load the utility method
seemingly randomly from different environments, and *not* always from the
environment assigend to the Puppet agent node for which the catalog is
compiled.

This is especially troublesome if there are different versions of the same
utility method in different environments.

## What does the module do?

The main class `functiontest` manages a simple text file
`/tmp/functiontest.txt` using a `file` resource. The contents of this file are
rendered by the custom parser function `envtestfunction` (defined in
`lib/puppet/parser/functions/envtestfunction.rb`). This parser function calls
upon a custom utility method `PuppetX::Functiontest::Utils.format_content`
(defined in `lib/puppet_x/functiontest/utils.rb`) to further format the content.

The utility method adds a comment to the file contents that mentions the
absolute path of the file in which the utility method is defined:

```
# functiontest library function at /etc/puppetlabs/code/environments/production/modules/functiontest/lib/puppet_x/functiontest
...
```

So this comment changes based on the Puppet environment assigned to the Puppet agent node:

```
$ puppet agent -t --environment production_test2
Info: Using configured environment 'production_test2'
Info: Retrieving pluginfacts
Info: Retrieving plugin
Info: Loading facts
Info: Caching catalog for node4-01.examle.com
Info: Applying configuration version '1515770853'
Notice: /Stage[main]/Functiontest/File[/tmp/functiontest.txt]/content:
--- /tmp/functiontest.txt       2018-01-12 16:26:07.666124367 +0100
+++ /tmp/puppet-file20180112-17544-18wj3s0      2018-01-12 16:27:43.618424002 +0100
@@ -1,4 +1,4 @@
-# functiontest library function at /etc/puppetlabs/code/environments/production/modules/functiontest/lib/puppet_x/functiontest
+# functiontest library function at /etc/puppetlabs/code/environments/production_test2/modules/functiontest/lib/puppet_x/functiontest

  This is static content from class functiontest.
...
```

# How does this issue manifest itself?

The way the utility method formats the file contents we can identify from which
environment the utility method is loaded. It *should* always reflect the
environment configured for the node, but that is often not the case, as you can
see in this example, where `production_test1` is the configured environment for
node `node4-01.example.com`, but the utility method used to render the contents
is loaded from `production_test3` for one Puppet agent run and then again from
`production_test1` for the next:

```
$ puppet agent -t
Info: Using configured environment 'production_test1'
Info: Retrieving pluginfacts
Info: Retrieving plugin
Info: Loading facts
Info: Caching catalog for node4-01.example.com
Info: Applying configuration version '1515771044'
Notice: /Stage[main]/Functiontest/File[/tmp/functiontest.txt]/content:
--- /tmp/functiontest.txt       2018-01-12 16:27:43.658424128 +0100
+++ /tmp/puppet-file20180112-18207-1awymtj      2018-01-12 16:30:53.531017416 +0100
@@ -1,4 +1,4 @@
-# functiontest library function at /etc/puppetlabs/code/environments/production_test1/modules/functiontest/lib/puppet_x/functiontest
+# functiontest library function at /etc/puppetlabs/code/environments/production_test3/modules/functiontest/lib/puppet_x/functiontest

 This is static content from class functiontest.


Info: Computing checksum on file /tmp/functiontest.txt
Info: FileBucket got a duplicate file {md5}c604419f0587eefae5bd4daaa2126622
Info: /Stage[main]/Functiontest/File[/tmp/functiontest.txt]: Filebucketed /tmp/functiontest.txt to puppet with sum c604419f0587eefae5bd4daaa2126622
Notice: /Stage[main]/Functiontest/File[/tmp/functiontest.txt]/content: content changed '{md5}c604419f0587eefae5bd4daaa2126622' to '{md5}c1d969685145b764f505186a411835db'
Notice: Applied catalog in 15.58 seconds

$ puppet agent -t
Info: Using configured environment 'production_test1'
Info: Retrieving pluginfacts
Info: Retrieving plugin
Info: Loading facts
Info: Caching catalog for node4-01.example.com
Info: Applying configuration version '1515771135'
Notice: /Stage[main]/Functiontest/File[/tmp/functiontest.txt]/content:
--- /tmp/functiontest.txt       2018-01-12 16:30:53.559017504 +0100
+++ /tmp/puppet-file20180112-18535-7hd53v       2018-01-12 16:32:24.119300636 +0100
@@ -1,4 +1,4 @@
-# functiontest library function at /etc/puppetlabs/code/environments/production_test3/modules/functiontest/lib/puppet_x/functiontest
+# functiontest library function at /etc/puppetlabs/code/environments/production_test1/modules/functiontest/lib/puppet_x/functiontest

 This is static content from class functiontest.


Info: Computing checksum on file /tmp/functiontest.txt
Info: FileBucket got a duplicate file {md5}c1d969685145b764f505186a411835db
Info: /Stage[main]/Functiontest/File[/tmp/functiontest.txt]: Filebucketed /tmp/functiontest.txt to puppet with sum c1d969685145b764f505186a411835db
Notice: /Stage[main]/Functiontest/File[/tmp/functiontest.txt]/content: content changed '{md5}c1d969685145b764f505186a411835db' to '{md5}c604419f0587eefae5bd4daaa2126622'
Notice: Applied catalog in 21.60 seconds
```

Not only does this lead to "oscillating" Puppet agent runs, it also means that
the file contents will be unexpectedly rendered differently because a different
version of the utility method (from another environment) is used. Imagine the
chaos that could ensue if this utility method were more complex or important.

# How to reproduce?

It is not too difficult to reproduce this issue, but it requires apparently at
least two Puppet agent nodes which are assigend two different Puppet
environments.

Simply add the module `functiontest` to the Puppetfile in your control repo's
`production` environment. Then create another environment, e.g.
`production_test1` in your control repo and add the `functiontest` module to
the Puppetfile. Lastly `include '::functiontest'` on at least two nodes, one in
each environment. It may be necessary to reload or even restart the
Puppetserver for it to pick up the new parser function, or rather, its utility
method:

```
puppetmaster01 $ systemctl restart puppetserver
```

Now start a few consecutive Puppet agent runs:

```
node01 $ for i in {1..30}; do puppet agent -t --environment production; sleep 60; done

node02 $ for i in {1..30}; do puppet agent -t --environment production_test1; sleep 62; done
```

After a few such Puppet agent runs you should see the contents of
`/tmp/functiontest.txt` changing and referencing the *other* environment
instead of the node's own environment.
