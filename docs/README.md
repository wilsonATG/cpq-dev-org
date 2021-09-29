**Cancel & Replace**

# cancel-and-replace
___

## What is this?

This is the Cancel and Replace solution. 

## Documentation

This version of Cancel and Replace will simply make a cancel and replace as usual. It deals witn the Too many SOQL queries limit error inserting the quote lines in batch per option level (First round, insert top level lines, second round insert level 1, then level 2 and so on). Too many DML sentences as levels has the amended quote.


## How do I use the Cancel & Replace library?

The following steps will need to be followed

___
1. Add the classes from this repository into your Org.
2. Create the custom fields on the Quote Line object. (Set up field permissions accordingly).
3. Add a button link in the Contract Object, and add it to the layout.


