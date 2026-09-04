These scripts compute the OSS contributor index to indicate the size of a contributor base for an open source software. 
The OSS contributor index is the number of contributors n with at least n commits to the repository.
This index is a coarse indicator of the size of a contributor base.

To compute the index run the batch_h_index.jl script from the SHELL directly. 
This assumes, that you have a GITHUB_TOKEN bash variable set to log into github because otherwise the download of the relevant info might be stopped. 

