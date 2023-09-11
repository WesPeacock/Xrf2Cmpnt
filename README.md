# Convert Crossref to Components

### Introduction

This repo contains scripts to convert a FLEx that has Lexical References from a Complex form to the entries that will be its components. It reads the Lexical Reference links and makes the entries to be components of the referred entry.

The FLEx SFM import process allows only one component per complex form. This allows you to import multiple components.

The first component of the SFM complex form will be imported as a regular component. Second and subsequent should be imported as special lexical references.

Note that if the crossref is at the sense level, FLEx calls it a Lexical Reference. In this document I'll just call it a crossref, whether it's at the sense level or at the entry level.

One of the included scripts will create components from the crossrefs.

After the components have been imported. You can delete the original crossrefs.

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
On a FLEx import, we can map the `\mn` field to indicate that the entry is a component of the complex form. However, the import process currently allows only one component to be marked this way. If the file is imported as is, the `\mn trap` field will be ignored.

The scripts mark second and subsequent components as special crossrefs. A Perl script then modifies the FLEx database to make the referenced entries to be components of the complex form.

### Steps to this Process

There are seven steps (XRC1-7) to this process:

XRC1. Modify the FLEx database to have a unidirectional Complex to Component crossref type.
XRC2. Add components to complex entries. If the entry is a sub-entry to be promoted don't add the main entry that it is under. The sub-entry promotion process will set that field.
XRC3. Change the SFM for components after the first component.
XRC4. Modify the import mapping so that *mnx* markers are mapped to the new crossref type.
XRC5. Import the SFM file. 
XRC6. Run the **Xrf2Cmpnt.pl** to add the crossrefs as components.
XRC7. Delete Complex/Component crossref type from the database.

### How this Process Fits in with the PromoteSubentry Process

There are 5 steps (PS1-5) of the PromoteSubentry Process. The above steps have been interspersed:

XRC1. Modify the FLEx database to have a unidirectional Complex to Component crossref type.
PS1. Import  *ModelEntries-MDFroot.db*  into Initial FLEx database to set up Model Subentries.
XRC2. Add components to complex entries. See note above.
PS2. Run **runse2lx.sh** subentry extraction and promotion.
XRC3. Change the SFM for components after the first component.
XRC4. Modify the import mapping so that *mnx* markers are mapped to the new crossref type.
PS3/XRC5. Import SFM file with Subentries.
PS4. Run **runVar2Compform.sh** to make the subentries into complex forms
PS5. Delete the  *"SubEntry Type Flag"* & Model Entries.
XRC6. Run the **Xrf2Cmpnt.pl** to add the crossrefs as components.
XRC7. Delete Complex/Component crossref type from the database.

### Infrastructure

#### Set UP WSL & Working Directory

The scripts in this repo require Linux **bash** and a properly configured **perl** system. These requirements are fulfilled if you follow the instructions here: [**Set up a Linux terminal**](https://sites.google.com/sil.org/importing-sfm-to-flex/workflow/i-set-up-infrastructure/b-set-up-a-linux-terminal).  Those instructions tell you how to set up a **WSL** terminal on Windows 10. That page also tells you how to navigate Windows directories from within **WSL**. (**WSL** is the **W**indows **S**ubsystem for **L**inux)

The instructions are part of the SIL Dictionary and Lexical Services **Importing SFM to FLEx: Best Practices** site.

Create or choose a working directory. It should be empty.

#### Download the Necessary Scripts

Instructions for how to download files from *github* are available from SIL Dictionary and Lexical Services **Importing SFM to FLEx: Best Practices** site, at: [How to download Perl scripts from GitHub](https://sites.google.com/sil.org/importing-sfm-to-flex/workflow/i-set-up-infrastructure/c-how-to-download-perl-scripts-from-github).

Download the following following scripts and files from [this repository](https://github.com/WesPeacock/Xrf2Cmpnt) on *github*:

* **Xrf2Cmpnt.pl** - script to add the crossrefs to components of the complex forms
* **Xrf2Cmpnt.ini** - control file
* **Xrf2Cmpnt.sh** --ignore for now
* **README.md**

Move the downloaded files into the working directory.

If you have Subentries to promote, download the necessary files from the Subentry Promotion process

#### Preparing the SFM database

XRC2) Add the component entries on complex forms. If the complex form is a sub-entry, do not add a link to the main form it is under. 

XRC3) After **runse2lx.sh** Mark 2nd & subsequent components as crossrefs. Can be just:

````bash
perl -CSD -pf opl.pl file.sfm | \
perl -CSD -pE 's/\\mn /\\firstmn /; s/\\mn /\\mnx /g; s/\\firstmn /\\mn /;' | \
perl -CSD -pf de_opl.pl >file-mod.sfm
````

#### Modify the FLEx Import



#### Prepare to run the scripts

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

When a component is added it is assumed that it show all the complex forms that it is a component of. We could make a special kind of crossref that maps it as a component, but that the complex form should not be displayed. In the **fwdata** file, using XPath notation */rt[@class='LexRefType']/*


***

#### About this Document

This document is written in Markdown format. It's hosted on *github.com*. The github site that it's hosted on will display it in a formatted version.

If you're looking at it another way and you're seeing unformatted text, there are good Markdown editors available for a Windows and Linux. An free on-line editor is available at https://stackedit.io/ 

This README was copied from the Gnr2SgPl README and may not have all the extraneous details corrected.

This repository was initialized with files from the Daasanach Gnr2SgPl repo.