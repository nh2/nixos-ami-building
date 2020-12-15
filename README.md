# Methods for building custom NixOS AMIs

This project demostrates various ways to build a custom NixOS AMI from a `configuration.nix` file.

It is largely excercises the methods shown in jackkelly's blog post
http://jackkelly.name/blog/archives/2020/08/30/building_and_importing_nixos_amis_on_ec2/.

## Overview

This README presents the following methods to create AMIs:

* Methods to build an AMI image file on your computer and then upload it:
  * Method 1: `nix-build`
  * Method 2: `nixios-generators`
  These methods build your image from scratch.
* Methods to build an AMI image on an EC2 machine:
  * Method 3: `packer`
    This method starts with an official NixOS AMI, applies your `configuration.nix`, and snapshots it into a new AMI.


## Prerequisites

All methods assume that you have:

* checked out the version of nixpkgs you want to use at `$HOME/src/nixpkgs`.
* Adjusted `./nixos/configuration.nix` to contain your desired NixOS config.


## Method 1: `nix-build`

```sh
NIX_PATH=nixpkgs=$HOME/src/nixpkgs \
  nix-build --no-out-link $HOME/src/nixpkgs/nixos/release.nix \
  --arg configuration nixos/configuration.nix \
  -A amazonImage.x86_64-linux
```

This prints to stdout the path to a dir containing the AMI `.vhd` file.


## Method 2: `nixos-generators`

[`nixos-generators`](https://github.com/nix-community/nixos-generators) is a small repo of wrapper scripts to build NixOS images with simple commands.

```sh
NIX_PATH=nixpkgs=$HOME/src/nixpkgs \
  $(nix-build --no-out-link https://github.com/nix-community/nixos-generators/archive/master.tar.gz)/bin/nixos-generate \
  -f amazon
```

This prints to stdout the path to a subdir of the dir containing the AMI (you have to strip the last 2 dirs off it to get to the `.vhd` file's dir).

The inner `nix-build` builts `nixos-generators` itself, and then we invoke its `nixos-generate` binary.
It picks up our `nixos/configuration.nix` by file naming conventions.


## Method 3: `packer`

In contrast to the previous methods, this requires having set up `~/.aws/credentials` because it will do the AMI building _on_ a throwaway EC2 machine that `packer` launches.
It starts the official NixOS AMI, applies your `configuration.nix`, and snapshots the result into a new AMI.
You can read a basic Packer tutorial [here](https://learn.hashicorp.com/tutorials/packer/getting-started-build-image).

I've saved jackkelly's Packer config in `./packer/nixos-packer-example.json`, and modified it to give the machine that does the AMI building a larger disk, to not run out of disk space (making sure that the `device_name` is the one for the root device of that instance type). The config uses `"most_recent": true` to select the most recent official NixOS image as a base.

In the below, replace `AWS_REGION=eu-central-1` by the region to create the AMI in.

```sh
NIX_PATH=nixpkgs=$HOME/src/nixpkgs \
  nix-shell --pure -p packer --run 'cd packer/ && AWS_REGION=eu-central-1 packer build nixos-packer-example.json'
```

With the Packer method you do not need import the AMI into EC2; Packer already does that for you.


## Importing built AMIs into EC2

You need an S3 bucket to upload the AMI to. jackkelly's blog post kindly provides a  CloudFormation template; I saved it saved in this repo under `./ami-importing/cloudformation/template.yaml`.

I then downloaded [this version of the nixpkgs `create-amis.sh` script](https://raw.githubusercontent.com/NixOS/nixpkgs/c376f3ec1196c881e72fa0236ab5b04f766b675a/nixos/maintainers/scripts/ec2/create-amis.sh) of `create-amis.sh` and modified it

> to comment out the calls to `make_image_public`, and also comment out the loop in upload_all that iterates across the regions

The result is in this repo under `./ami-importing/create-amis.sh`.

Steps to upload the AMI:

1. Open CloudFormation in the AWS console, and import `./ami-importing/cloudformation/template.yaml` into it. This creates an S3 bucket for you.
  * Be aware that the bucket is created in the AWS region that you've currently chosen (in the top right). Note down that region.
2. Open S3 in the AWS console, and figure out the name of the created S3 bucket.
   It should look like `nixos-ami-building-vmimportbucket-prf5j5yydsx3`.
4. Edit `./ami-importing/create-amis.sh`, replacing:
  * the `home_region=` variable by the region that you created your bucket in
  * the `bucket=` variable by your bucket name
3. Configure your `~/.aws/credentials` file so that the `aws` CLI utility has access to your AWS account. (This is outside the scope of this README, but easy to find docs for.)
4. Run the script (replace the path to the dir containing the AMI `.vhd` by your own):

    ```sh
    NIX_PATH=nixpkgs=$HOME/src/nixpkgs \
      ami-importing/create-amis.sh \
      /nix/store/1wgfx4m76bcmdyzsw49pvs13l6gl6gim-nixos-amazon-image-20.09beta-111781.gfedcba-x86_64-linux/
    ```

    <details>
      <summary>Click to expand issues of the upload script itself</summary>
      Note that as of writing, like most shell scripts, the script doesn't do proper error handling:
      On success, no exit code is set, and it continues to run subsequent steps even if earlier steps failed because you haven't configured AWS credentials.
      Don't do shell scripts.
    </details>

After this, you should find the AMI in your EC2 AMI list.


### Troubleshooting

<details>

<summary>Click to expand Troubleshooting section</summary>

* `The given S3 object is not local to the region`
  * The `home_region=` in the upload script does not match your bucket's region.
* Upload error `when calling the CreateMultipartUpload operation: Access Denied`
  * You either have not configured `~/.aws/credentials`, or `bucket=` in the upload script does not match your bucket's name.
* What does a successful `create-amis.sh` invocation look like?
  Roughly like this:
  ```
  Image Details:
   Name: NixOS-20.09.git.6608ea8eb6a-x86_64-linux
   Description: NixOS 20.09.git.6608ea8eb6a x86_64-linux
   Size (gigabytes): 3
   System: x86_64-linux
   Amazon Arch: x86_64
  Checking for image on S3
  2020-12-14 22:28:29 1506129408 nixos-amazon-image-20.09.git.6608ea8eb6a-x86_64-linux.vhd
  Importing image from S3 path s3://nixos-ami-building-vmimportbucket-prf5j5yydsx3/nix/store/fqai90z1wl2blxchf7hzbbjk02zis8w7-nixos-amazon-image-20.09.git.6608ea8eb6a-x86_64-linux/nixos-amazon-image-20.09.git.6608ea8eb6a-x86_64-linux.vhd
  Waiting for import task import-snap-0775c26f8f757319d to be completed
   ... state=active progress=2 snapshot_id=null
   [..]
   ... state=active progress=94 snapshot_id=snap-0054ec2e7d6bf866d
   [..]
   ... state=completed progress=null snapshot_id=snap-0054ec2e7d6bf866d
  Registering snapshot snap-0054ec2e7d6bf866d as AMI
  {
    "eu-central-1.x86_64-linux": "ami-06743a1c5bc56e348"
  }
  ```

</details>
