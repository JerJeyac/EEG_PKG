# EEG_PKG
A complete EEG analysis package for custom 4x1 HD-tDCS recording setup for measuring pre-post simulation effects on EEG response.

This project was designed to work with a 4x1 HD-tDCS set-up using Brain-Vision V-amp combined with an EyeLink trigger: 

http://brainvision.co.uk/v-amp

The equipment was set up to output a CSV file with headers: TIME|E1|E2|...|EN|TRIGGER|FREQ|. With the 4x1 set-up used only E1-E5 were referred to in the script. E1 denotes the centre electrode, whereas E2-E5 denotes the 4 flanking electrodes. 

EEGMerge are templates of how the file structure is generated for the main processing scripts. Sample toy data will be provided in the future so it's easier to get an idea without having to read the comments within the code.

The main processing pipeline is easily done by the following: 

~~~
EEG = ProcessEEG('output of merging script.mat')
~~~

This generates an object of EEGMatrixHandler class which contains a range of functions for generating visualizations, statistical analysis, and comparative analysis. EEGMatrixHandler supports both TFR and Time-Series analysis of EEG signals. By default a Surface Laplacian is computed over the 5 electrodes toward the centre electrode and a pseudo-Z score is computed. 

TO-DO: Provide toy random example and play script.
