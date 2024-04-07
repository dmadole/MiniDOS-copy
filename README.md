# Elfos-copy

This is a copy  utility for Elf/OS 4 or earlier, able to copy single files, or all the files in a directory (but nor recursively).

If the source path names a directory, the files in that directory will be copied. In this case, if the target path names an existing directory, the files are copied into it. Or, if there is nothing at the target path, the named directory will be created, then the files copied into it. It is an error if the target path names an existing file.

If the source path names a file, that single file is copied. In this case, if the target path names an existing file, that file will be overwritten. Or, if the target path names an existing directory, the file will be copied into that directory. However, if there is nothing at the target path, and the target name ends in a slash, a directory will be created and the file copied into it, otherwise, the file will be copied to a file with the target name.

When the source path is a directory, the user will be asked to confirm a directory copy is intended. Ending the source path with a slash suppresses this confirmation, excepting for the root directory. Or, specifying the -d option suppresses this confirmation in all cases including for the root directory.

Path names of directories may be given with trailing slashes or not, with slight changes to behavior as noted.

The -v option will display the source and target path names as they are copied.
