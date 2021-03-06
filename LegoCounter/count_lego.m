function [numA,numB]=count_lego(I)
%% Introduction 
% Please Note that the output vairables are NumA and NumB; The Ans variable
% could not be suppressed and displays the value for NumA;

% The following function uses an Aggregate Channel Features (ACF) Algorithm,
% to train a Machine Learning Model to detect the shapes of Lego pieces.
% The steps used to train the model were derived from the literature [1].
% Initially, images are labelled and then passed through an ACF trainer 
% which in turn extract key features in order to train the detection model.
% Over 500 images were manually labelled to train both the models used 
% within this piece of work; the unlabelled training data was obtained 
% from a single data base [2]. An example of the training data can be found
% in the examples folder.

% ACF detectors work best with true colour images, however, a data base of 
% colour Lego images was not available. The provided training data in 
% conjunction with stock images was used to train the first iteration of 
% the ACF detector, however, this was abandoned as utilising the test 
% images to both train and test the model would have resulted in a large 
% degree of overfitting.

% The count Lego function utilises two trained ACF detectors. The first ACF
% detector is trained to identify square Lego pieces.  The second is
% trained to detect rectangular Lego pieces. Once the test images are pass 
% through the argument of the count Lego function, the images are used to
% create two separate image Masks based on selected histogram thresholds.
% Thus, two images are created. One which only contains objects that are 
% Red, and another that contains objects that are blue. The images are then 
% converted to grayscale and then passed through the ACF detector. Which
% returns a confidence score, and the location of the object. 

% The colour thresholding method is sometimes unable to accurately remove 
% Lego pieces of similar hues, which results in a number of false 
% positives.  In order to reduce the number of false positives, image
% segmentation and Blob analysis is used as a failsafe [3]. 
% 
% Example case; the thresholding method is applied to remove all the 
% non-red Lego pieces (i.e. segment the image), however, sections of a few
% orange Lego pieces still remain in the image, which may result in several
% false positives. Blob analysis is used to count the total number of Red
% pieces in the image. If the total number of Red Lego pieces in the image 
% is less than the total number of ACF matches the ACF detection has 
% failed. In this case the algorithm counts the number of Red Lego squares
% using more classic computer vision techniques. First, the size of all 
% the Red blobs is obtained, and passed through a threshold of empirically 
% derived data to isolate which are squares and which are rectangles.

%% References

% [1] https://uk.mathworks.com/help/vision/ref/trainacfobjectdetector.html
% [2] https://www.kaggle.com/joosthazelzet/lego-brick-images
% [3] https://uk.mathworks.com/help/vision/ref/blobanalysis.html
% [4] https://uk.mathworks.com/help/vision/ref/selectstrongestbbox.html
 
%% Loading ACF Model
% Load Rectangle Detector
load('RECacfDetector.mat')
% Load Square Detector 
load('ACF135')
%% Colour Thresholding: Removes all non-RED image data
% Convert RGB image to HSV
IH = rgb2hsv(I);

% Channel 1 threshold
Rchannel1Min = 0.938;
Rchannel1Max = 0.041;
% Channel 2 threshold
Rchannel2Min = 0.471;
Rchannel2Max = 1.000;
% Channel 3 threshold
Rchannel3Min = 0.000;
Rchannel3Max = 1.000;

% Histogram thresholds used to create Mask and Segment image 
RsliderBW = ( (IH(:,:,1) >= Rchannel1Min) | (IH(:,:,1) <= Rchannel1Max) ) & ...
    (IH(:,:,2) >= Rchannel2Min ) & (IH(:,:,2) <= Rchannel2Max) & ...
    (IH(:,:,3) >= Rchannel3Min ) & (IH(:,:,3) <= Rchannel3Max);
RBW = RsliderBW;
REDmaskI = I;
REDmaskI(repmat(~RBW,[1 1 3])) = 0;

RED_output = rgb2gray(REDmaskI);

%% Colour Thresholding: Removes all non-BLUE image data
%  Channel 1
Bchannel1Min = 0.575;
Bchannel1Max = 0.637;
% Channel 2 
Bchannel2Min = 0.497;
Bchannel2Max = 1.000;
% Channel 3
Bchannel3Min = 0.000;
Bchannel3Max = 1.000;

% Histogram thresholds used to create Mask and Segment image 
BsliderBW = (IH(:,:,1) >= Bchannel1Min ) & (IH(:,:,1) <= Bchannel1Max) & ...
    (IH(:,:,2) >= Bchannel2Min ) & (IH(:,:,2) <= Bchannel2Max) & ...
    (IH(:,:,3) >= Bchannel3Min ) & (IH(:,:,3) <= Bchannel3Max);
BBW = BsliderBW;
BmaskedRGBImage = I;
BmaskedRGBImage(repmat(~BBW,[1 1 3])) = 0;
BLUE_output = rgb2gray(BmaskedRGBImage);

%% Image Detection BLUE
[BLUE_bboxes,BLUE_scores] = detect(RECacfDetector,BLUE_output);
% Select strongest Scores
[BLUE_selectedBbox,BLUE_selectedScore] = selectStrongestBbox(BLUE_bboxes,BLUE_scores,'OverlapThreshold',0.08);
[RED_bboxes,RED_scores] = detect(acfDetector,RED_output);
%% Image Detection RED
% Select strongest Scores
[RED_selectedBbox,RED_selectedScore] = selectStrongestBbox(RED_bboxes,RED_scores,'OverlapThreshold',0.08);
%% Blob Analysis Check; Counts the number of Red and Blue objects in image 
diskElm = strel('disk',10);
RIbwopen = imopen(RsliderBW, diskElm);
%% Red; Blob Analysis
REDBlobAnalysis = vision.BlobAnalysis('MinimumBlobArea', 8000, ...
    'MaximumBlobArea',  100000);
[RobjectArea, RobjectCentroid, RbboxOut] = step(REDBlobAnalysis, RIbwopen); % Area of the blob and the centre
Red_Limit = length(RobjectArea);

%%
RED = [];
for i = 1:length(RED_selectedScore)
    if RED_selectedScore(i) > 20
       RED(i) = RED_selectedScore(i);
      
   end
end
Red_Count= sum(RED>0);


RC = [];
  if Red_Count > Red_Limit
      for i = 1:length(RobjectArea)
        if RobjectArea(i)> 16779
            if RobjectArea(i) < 39090
               RC(i) = RobjectArea(i);
               Red_Count= sum(RC>0);
           
            end
        end
      end
  end
 

BLUE = [] ;
for i = 1:length(BLUE_selectedScore)
    if BLUE_selectedScore(i) > 20
       BLUE(i) = BLUE_selectedScore(i) ;
   end
end
 
 
 
BC = [];
  if Red_Count > Red_Limit
      for i = 1:length(RobjectArea)
        if RobjectArea(i)> 16779
            if RobjectArea(i) < 39090
               RC(i) = RobjectArea(i);
               Red_Count= sum(RC>0);
            end
        end
      end
  end

numA = sum(BLUE>0)
numB = Red_Count
end