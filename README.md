dvdivvy
=======

OS X Cocoa app to split up long video files into individual episodes

More info in my blog at http://www.subfurther.com/blog/2013/10/05/dvdivvy/

![dvdivvy-screenshot-true-tears](https://cloud.githubusercontent.com/assets/305140/5320984/2cbc3c3e-7c85-11e4-818d-3a3ed67f19d6.png)

Known bugs / TODOs:
* Deleting last segment raises exception
* Table should clear when a different movie is opened
  * Related / bigger issue: decide if this is a one-window application (opening one source takes you out of the last one) or a multi-window / Document-based application (opening a source opens a new window, with its own state)
* Destination button’s NSSavePanel sheet’s directory dialog button shouldn’t say “Export” (suggests that export will begin immediately)
* On window resize, would be more useful for preview to stretch horizontally than table
