# Crossreference Convert to Components

### Introduction

This repo contains scripts to convert a FLEx that has Unidirectional Cross References that point from a Component to its Complex form. It converts them to Components of the referred entry.

The FLEx SFM import process allows only one component per complex form. This allows you to import multiple components.

The first component of the SFM complex form should be imported as a regular component. Second and subsequent should be imported as special Unidirectional Crossreferences/Lexical Relations. The included scripts will convert them to components.

#### About this Document

This document is written in Markdown format. It's hosted on *github.com*. The github site that it's hosted on will display it in a formatted version.

If you're looking at it another way and you're seeing unformatted text, there are good Markdown editors available for a Windows and Linux. An free on-line editor is available at https://stackedit.io/ 

This README was copied from the Gnr2SgPl README and may not have all the extraneous details corrected.

### An Example

Let's consider an English complex form "bear trap". It has two components "bear" and "trap." A simple SFM file for the entries might look like this:

````SFM
\lx bear
\ps n
\de a large omnivorous mammal

\lx bear trap
\mn bear
\mn trap
\ps n
\de a large trap used to catch a bear or other mammal, usually as a foot trap

\lx trap
\ps n
\de a machine or other device designed to catch animals
````
On a FLEx import, we can map the `\mn` field to indicate that this is a component of the complex form. However, the import process allows only one component to be marked this way.

### Preparation

#### Infrastructure

The scripts in this repo require Linux **bash** and a properly configured **perl** system. These requirements are fulfilled if you follow the instructions here: [**Set up a Linux terminal**](https://sites.google.com/sil.org/importing-sfm-to-flex/workflow/i-set-up-infrastructure/b-set-up-a-linux-terminal).  Those instructions tell you how to set up a **WSL** terminal on Windows 10. That page also tells you how to navigate Windows directories from within **WSL**. (**WSL** is the **W**indows **S**ubsystem for **L**inux)

The instructions are part of the SIL Dictionary and Lexical Services **Importing SFM to FLEx: Best Practices** site.

Create or choose a working directory. It should be empty.

#### Prepare the SFM database

Add the component entries on Complex forms.

#### Prepare to run the scripts

Instructions for how to download files from *github* are available from SIL Dictionary and Lexical Services **Importing SFM to FLEx: Best Practices** site, at: [How to download Perl scripts from GitHub](https://sites.google.com/sil.org/importing-sfm-to-flex/workflow/i-set-up-infrastructure/c-how-to-download-perl-scripts-from-github).

Download the following following scripts and files from [this repository](https://github.com/WesPeacock/Xrf2Cmpnt) on *github*:

* **Xrf2Cmpnt.ini**
* **Xrf2Cmpnt.pl**
* **Xrf2Cmpnt.sh** --ignore for now
* **README.md**

Move the downloaded files into the working directory.

Edit the **Xrf2Cmpnt.ini** file and choose values for the following lines:

````ini
xrefAbbrev=Cmpnt
LogFile=Xrf2Cmpnt.log
````
Names of the items are on the right hand side of the equals sign. Don't put any spaces before or after the name.

#### Run the scripts

Navigate to the working directory within **WSL**.

There should be a copy the *.fwbackup* file from the location you noted when you created it, in the working directory.

In **WSL**, type:
	**dos2unix** **\***
This converts the script and control file line endings.

In **WSL**, type:

​	**./Xrf2Cmpnt.pl** 

That script produces a log file with a list of all the entries that would be changed by running **FixSgPl.pl**. The user should edit the log file and flag entries that shouldn't be changed.

#### Run FLEx to check your results

You can run FLEx and restore the project from the backup to verify that the Examples are numbered.

### Issues

In Process.


***

This repository was initialized with files from the Daasanach Gnr2SgPl repo.