# talend-aws-baseline

These scripts work together with the Talend Unattended Installer (TUI) and Talend AWS Cloud Formation templates
to install Talend on EC2 instances.

### Cloud Formation Templates

The Cloud Formation templates populate dependencies, e.g. database hostnames, ports, etc, into shell scripts
which are used to populate OS environment environment variables.  These shell scripts are sourced prior to
running the installer.  The  environment values are imported by the installer configuration files to
initialize configuration values which are in turn used by the TUI installer.

### TUI

TUI is a groovy application for installing Talend components.  It is data driven using Groovy configuration
files.  These Groovy scripts are similar to, but much more powerful than java property files.  They also
support interpreating environment variables.

There are many other configuration settings which may be customized but which are not passed via the Cloud
Formation templates.  These settings can be manually tweaked in these configuration scripts themselves, or
entererd into a supporting setenv.sh file and then referenced like the other environment variables from the
configuration scripts.

### Referencing Environment Variables from Configuration Scripts

To reference environment variables from the Groovy configuration scripts, follow the Groovy syntax.

Declare a top level Groovy variable and initialize it to the system environment variables.  The
`env` variable below is a Map that is populated with environment values.  It is then used to initialize
the `root_dir` variable.

    def env = System.env()
    
    ...
    
    root_dir = env['TALEND_REPO']

### Environment Variables

The `setenv.sh` file will be created by the Cloud Formation scripts.  The sample provided here is for
test purposes.

**The setenv.sh file must be sourced rather than invoked as a child script.**

The `tui` installer must be run as `sudo`, so keep in mind to use the `-E` command flag to preserve the
environment. 

    source setenv.sh
    sudo -E ./install tac

The two commands above will initialize the environment and then invoke the tui installer.

### Merging Configuation Files with TUI

The files in the `tui` directory have been extracted from the TUI installer and modified to work in the
Talend AWS Quickstart environment.  They need to be merged with the TUI installer on each EC2 instance node.
This will be done the Cloud Formation templates.  For this reason the file and directory structure of the
`tui` directory mirror that of the TUI installation tool.

### Scripts

#### Update Hosts

Amazon EC2 Linux instances cannot resolve their own private host names.  The `update_hosts.sh` script modifies
the `/etc/hosts` file and the `/etc/sysconfig/network` file with information from the AWS REST reflection API
to fix this situation.  This ensures that TUI can operate with all of the default values.

#### JRE Installer

An alternatve to the TUI installer is provided in the scripts/java directory.  The jre-installer.sh will install the JRE from a previously
downloaded tgz file.  Since the Quickstart repository will typically be attached as an s3fs mount, this will typically be slightly faster and it will make the environment self-contained.

### Quickstart Configuration

There are three s3 buckets used by the Quickstart.

* License
* Baseline
* Repo Bucket

The Baseline and Repo buckets are common to all users.

#### License Bucket

The License bucket contains the user's Talend license.  This bucket should only be accessible by the Taled
license owner.  When a customer with a subscription wishes to re-use these assets in their own Cloud Formation
infrastructure, they can create their own bucket, load their license to that private location, and point
to it in their Cloud Formation scripts.

#### Baseline Bucket

The Baseline bucket hosts a snapshot of this git repository.  At runtime the templates directory
is accessed by the Cloud Formation engine to launch the master and nest templates.

The scripts/bootstrap directories are used by the userdata scripts to ensure the aws ec2 instance can resolve its
own hostname so that TUI will work.

The scripts/java directory contains a script to install the JRE.  It can either download the JRE from
the Oracle online sources or use a tgz file that has already been downloaded.  It is used by the Talend
templates to install Oracle JRE on Talend servers.

The `install` script in the `scripts/conf` directory uses the `scripts/factory` to create new Quickstart configuration
buckets.  The Quickstart factory allows users to provision their own customized Quickstart Baseline and Repository buckets.

#### Repo Bucket

All Talend binaries are stored in this bucket.  When run in the Quickstart environment there is a single
Repo bucket referenced by all users.  When a customer wants to create and customize their own Cloud
Formation environment they can use the factory scripts in the baseline bucket (or git repo) to provision
this bucket using TUI.

#### Using the Factory

To use the factory you will need a machine with the AWS CLI installed.  It is recommended to simply
use a new EC2 instance.  A micro size is sufficent.

First, install the git client

    sudo yum install git

Next, clone the Talend Baseline git repository

    git clone https://github.com/EdwardOst/baseline.quickstart.talend.git

Go to the new directory

    cd baseline.quickstart.talend

Some AWS instances are not able to resolve their host ip.  This is a problem for the Talend Unattended
Installer (TUI).  Check if your host has this problem

    hostname -i

If the command above does not resolve to an IP address then run the update_hosts.sh script in the bootstrap directory.

    sudo bootstrap/update_hosts.sh

Talend requires the Oracle JRE, not the OpenJRE that comes with AWS images.

    sudo java/jre-installer.sh

The factory uses both the AWS S3 CLI as well as the [s3fs](https://github.com/s3fs-fuse/s3fs-fuse).
If you are not using an IAM role with your EC2 instance, then you will need to configure your AWS
credentails.

    aws configure

Create a new directory to run your factory setup.

    cd ~
    mkdir factory_setup
    cd factory_setup

You will need two files.  One is your Talend license file.  If you are doing a factory setup rather
than just running the Quickstart then you should have received an evaluation license from your Talend
account manager.  Download it to your `factory_setup` directory.

The other file is the Talend Unattended Installer (TUI) binary.  Dowload TUI to the `factory_setup`
directory from the public Talend Quickstart repository.

    wget https://s3.amazonaws.com/repo-quickstart-talend/tui/TUI-4.5.2.tar

Run the installer as sudo

    sudo /home/ec2-user/baseline.quickstart.talend/scripts/conf/install

It will prompt you for your AWS credentials and your Talend credentials.  These will be used during
the factory setup and saved to a file with read-only privileges for the current user (which will be
root).
