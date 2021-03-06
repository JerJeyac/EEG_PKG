%%Organization script for automated loading into EEG program.
%Run this program on a copy of the original DMAT files in case of
%corruption etc...
%Use this program prior to EEG analysis on DMAT files with filename type:
%IIASCCBD.mat.mat
% Where:
% I is intials
% A is area of stimulation
% S is stimulation type
% C is condition type
% B is block number
%Written by - Jerry Jeyachandra 2016
%Output Structure - %S--> subjects --> A/C --> Pre/Post --> D Matrices/EEG Data

%Structure of Grouping Matrix (*.T)
%{
1. Trial Start
2. Target Onset
3. Time of Movement Onset
4. Separating Column (999999) 
5. Median Split
6. Left Hemifield 
7. Right Hemifield
8. Reach
9. No Grouping
10.Target
11.Initial Hand Position
%}

%TO-DO: Nothing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Get Directory
clear;
p = uigetdir('Select location of DMats...');
cd(p);

F = dir;

%Remove filesystem rows
F([F.isdir] == 1) = [];

%% Create all uppercase field to eliminate issue of case-sensitivity in many of MATLAB's functions
upperCell = upper({F.name});
upperStruct = cell2struct(upperCell,'uName',1);
[F(:).uName] = deal(upperStruct.uName);

%%  Initialize variables
%Indices based on standardized file name schema, change here if you have a
%different schema - rest of script should work fine.
ind_stim = 4;
ind_initial = 1:2;
ind_cond = 5:6;
ind_block = 7;
f_stim = {'Anodal' 'Cathodal'};
f_cond = {'Pre' 'Post' 'Stim'};
E = struct;
merge_T = [];

IHP_POS = [-7.5 7.5];
TARG_POS = [-10 -5 5 10];

sp = uigetdir('Select location of saved MAT file...');
time = clock;
strFile = ['[' num2str(time(1)) '-' num2str(time(2)) '-' num2str(time(3)) '-' num2str(time(4)) '-' num2str(time(5)) ']' ];
save([sp '\EEGStructARM' strFile], 'E', '-v7.3');

%% Sort Struct (just in case filesystem sorts weirdly...)
FCell = struct2cell(F);
FFields = fields(F);
szF = size(FCell);
FCell = reshape(FCell, szF(1), []);
FCell = FCell';
FCell = sortrows(FCell,1);
FCell = reshape(FCell',szF);
FSorted = cell2struct(FCell,FFields,1);
cell_F = struct2cell(FSorted);
fNameC = {FSorted.uName};

%% Get all subject initials, stimulation types and conditions
sub_initials = unique(cellfun(@(x) x(ind_initial), cell_F(end,:), 'un', 0))';
cond_type = sortrows(unique(cellfun(@(x) x(ind_cond), cell_F(end,:), 'un', 0)))';
%(1*)
cond_type(end) = [];
cond_type = flipud(cond_type);

stim_type = sortrows(unique(cellfun(@(x) x(ind_stim), cell_F(end,:), 'un', 0)))';

%Data structure for storing conditional indexing information 
T = table; 
T_test = []; 
delCount = 0; %To account for removals due to early start
%% Organize struct
for s = 1:length(sub_initials)
    
    %Grab all files with subject initials
    subInd = ~cellfun('isempty',strfind(cellfun(@(x) x(ind_initial), fNameC, 'un', 0),sub_initials{s}));
    
    tMovementList = [];
    for stim = 1:length(stim_type)
        
        %Divide into anodal/cathodal conditions
        stimInd = ~cellfun('isempty',strfind(cellfun(@(x) x(ind_stim), fNameC, 'un', 0),stim_type{stim}));
        
        for cond = 1:length(cond_type)
            
            %Divide into pre/post conditions (since no STIM EEG)
            condInd = ~cellfun('isempty', strfind(cellfun(@(x) x(ind_cond), fNameC, 'un', 0), cond_type{cond}));
            
            %Logical containing struct indices pertaining to file with
            %specific sub,stim,cond.
            all_Ind = subInd & stimInd & condInd;
            cur_Struct = FSorted(all_Ind);
            
            %Initialize transient variables
            merge_S = [];
            merge_EEG = [];
            merge_END = [];
            merge_T = []; 
            counter = 1;
            
            %Load files, merge DMATs, EEG and organize into struct
            
            for m = 1:sum(all_Ind)
                curFile = load(cur_Struct(m).name);
                
                
                if (~isfield(curFile.D{1},'eegData'))
                    disp(cur_Struct(m).name);
                end
                
                %Merge if EEG is complete or if trigger is valid
                if (isfield(curFile.D{1},'eegData') && ~isnan(mean(curFile.D{1}.eegData(:,1))) && ~sum(find(curFile.D{1}.eegData(:,20) == 255)))
                    
                    %Merge EEG and assign block number
                    merge_EEG = [merge_EEG; curFile.D{1}.eegData(:,[1:6 20]) m*ones(size( curFile.D{1}.eegData,1),1)];

                    X = [curFile.D{2:end}];
                    
                    %Grab relevant events for EEG alignment
                    tStart = [curFile.D{1}.tStart [X(:).tStart]];
                    tTarget = [curFile.D{1}.tTarget [X(:).tTarget]];
                    tRsp = [curFile.D{1}.tRsp [X(:).tRsp]];
                    tFix = [curFile.D{1}.tFixation [X(:).tFixation]];
                    tMovStart = [curFile.D{1}.tMotStart [X(:).tMotStart]];
                    
                    %Get target and ihp position indices
                    targPosI = [curFile.D{1}.tarI [X(:).tarI]];
                    fingerPosI = [curFile.D{1}.fingerI [X(:).fingerI]];
                    
                    %Map onto locations
                    targLoc = TARG_POS(targPosI);
                    ihpLoc = IHP_POS(fingerPosI);
                    
                    %Left = 1, Right = 2
                    lrReach = (targLoc > ihpLoc) + 1;
                    lrTarg = (targLoc > 0) + 1;
                    lrIHP = (ihpLoc > 0) + 1; 

                    %Target AND IHP coding
                    lSide = (lrTarg == 1 & lrIHP == 1); 
                    rSide = (lrTarg == 2 & lrIHP == 2);
                    
                    %Code for cross-hemifield reaches 
                    loSide = (lrTarg == 2 & lrIHP == 1);
                    roSide = (lrTarg == 1 & lrIHP == 2);
                    
                    %Target in same side as IHP, 2 - yes, 1 - no
                    hemiL = lSide + 2*loSide; 
                    hemiR = rSide + 2*roSide; 
                    
                    %Excusive Hemifield 2- left, 1- right
                    eHemi = lSide + 2*rSide; 
                    
                    %Reaction Time List
                    tRT = tMovStart - (tTarget - tStart); 
                    
                    %Short fix for misaligned EEG issues... look into files
                    %later... 
                    
                    Q = tTarget - tStart; 
                    tStart(Q > 4000) = NaN; 
                    tTarget(Q > 4000) = NaN;                 
                    
                    %Directional coding of reach vector
                    %Assign values based on index
                    reachVec = targLoc - ihpLoc; 
                    
                    %Get combination of targetIHP for TFR analysis
                    targIHP = targPosI + 4*(fingerPosI - 1);
                    targ = targPosI; 
                    
                    %Adjust T*IHP interaction effect 
                    TIHP = zeros(length(targIHP),1); 
                    TIHP(targIHP == 1 | targIHP == 2) = 1; 
                    TIHP(targIHP == 3 | targIHP == 4) = 2; 
                    TIHP(targIHP == 5 | targIHP == 6) = 3; 
                    TIHP(targIHP == 7 | targIHP == 8) = 4; 
                    
                    
                    %Cumulative merged values across blocks 
                    merge_T(:,:,counter) = [tStart' tTarget' tMovStart'+tStart']; 
                        
                    
%                     999999*ones(size(tMovStart,2),1) TIHP targIHP' reachVec' ...
%                             eHemi' hemiL' hemiR' lrReach' lrTarg' ...
%                                 ones(size(tStart,2),1) lrIHP' tRT'];
                            
                    %Convert matrix to table form (unidentified headers) 
                    %Default set up: 
                    %Subject, Stim, Cond, Block, Trial, Inds
                    numTrials = ones(size(tRT',1),1); %Any variable size can be used... 
                    T_add = table(s.*numTrials,stim.*numTrials,cond.*numTrials,...
                        m.*numTrials, [1:length(numTrials)]',TIHP,targIHP',...
                            reachVec',eHemi',hemiL',hemiR',lrReach',lrTarg',numTrials,lrIHP',tRT'); 
                        
                    
                    %Removal of bad trials 
                    trialMark = [curFile.D{1}.good [X(:).good]];
                    badInd = trialMark == 1;
                    merge_T(badInd,:,counter) = NaN; 
                    
                    %Search for NaNs applied and from actual recording
                    %errors
                    T_add(isnan(merge_T(:,1,counter)),:) = []; 
                    
                    %Short fix for EEG start after trial begins
                    if (curFile.D{1}.eegData(1,20) == 3)
                        merge_T(1,:,counter) = 0; 
                        T_add(1,:) = []; 
                        delCount = delCount + 1; 
                    end
                    
%                     tMovementList = [tMovementList; tRT' counter*ones(size(tRT')) ...
%                         cond*ones(size(tRT')) stim*ones(size(tRT'))];
                    counter = counter + 1; 
                    
                    T = vertcat(T,T_add); 
                    T_test = [T_test; merge_T(:,:,counter-1)]; 
                    
                end
            end
            
            if (any(merge_T))
                %Construct struct containing organized info.
                E(s).(f_stim{stim}).(f_cond{cond}).EEG = merge_EEG;
                E(s).(f_stim{stim}).(f_cond{cond}).T = merge_T;
                
                %Test, build on current set 
                T_test(isnan(T_test(:,1)),:) = []; 
                if (height(T)+delCount ~= size(T_test,1))
                    error('Non-matching sets!');  
                end
            end
        end
        
    end
    
    %% Compute the median of the subject's reaction times
%     subMedian = nanmedian(tMovementList(:,1));
%     tMovementFilt = (tMovementList(:,1) > subMedian) + 1;
%     
%     %Assign median split information (this is horrible practice...)
%     
%     %Anodal Pre
%     tMovementAnodePre = tMovementFilt(tMovementList(:,3) == 1 & tMovementList(:,4) == 1,1);
%     E(s).Anodal.Pre.T = [E(s).Anodal.Pre.T(:,1:4,:) reshape(tMovementAnodePre,size(E(s).Anodal.Pre.T,1),1,size(E(s).Anodal.Pre.T,3)) E(s).Anodal.Pre.T(:,5:end,:)];
%     
%     %Get NaNs
%     APreNaN = isnan(E(s).Anodal.Pre.T(:,:,:));
%     APreNaN(:,5,:) = APreNaN(:,1,:);
%     E(s).Anodal.Pre.T(APreNaN) = NaN;
%     
%     %Anodal Post
%     tMovementAnodePost = tMovementFilt(tMovementList(:,3) == 2 & tMovementList(:,4) == 1,1);
%     E(s).Anodal.Post.T = [E(s).Anodal.Post.T(:,1:4,:) reshape(tMovementAnodePost,size(E(s).Anodal.Post.T,1),1,size(E(s).Anodal.Post.T,3)) E(s).Anodal.Post.T(:,5:end,:)];
%    
%     %Get NaNs
%     APostNaN = isnan(E(s).Anodal.Post.T(:,:,:));
%     APostNaN(:,5,:) = APostNaN(:,1,:);
%     E(s).Anodal.Post.T(APostNaN) = NaN;
%     
%     %Cathodal Pre
%     tMovementCathodePre = tMovementFilt(tMovementList(:,3) == 1 & tMovementList(:,4) == 2,1);
%     E(s).Cathodal.Pre.T = [E(s).Cathodal.Pre.T(:,1:4,:) reshape(tMovementCathodePre,size(E(s).Cathodal.Pre.T,1),1,size(E(s).Cathodal.Pre.T,3)) E(s).Cathodal.Pre.T(:,5:end,:)];
%    
%     %Get NaNs
%     CPreNaN = isnan(E(s).Cathodal.Pre.T(:,:,:));
%     CPreNaN(:,5,:) = CPreNaN(:,1,:);
%     E(s).Cathodal.Pre.T(CPreNaN) = NaN;
%     
%     %Cathodal Post
%     tMovementCathodePost= tMovementFilt(tMovementList(:,3) == 2 & tMovementList(:,4) == 2,1);
%     E(s).Cathodal.Post.T = [E(s).Cathodal.Post.T(:,1:4,:) reshape(tMovementCathodePost,size(E(s).Cathodal.Post.T,1),1,size(E(s).Cathodal.Post.T,3)) E(s).Cathodal.Post.T(:,5:end,:)];
%    
%     %Get NaNs
%     CPostNaN = isnan(E(s).Cathodal.Post.T(:,:,:));
%     CPostNaN(:,5,:) = CPostNaN(:,1,:);
%     E(s).Cathodal.Post.T(CPostNaN) = NaN;
      
    %% Assign subject initial to each row of struct array
    E(s).subInitials = sub_initials(s);
    save([sp '\EEGStructARM' strFile],'E', '-append');
end
%Stick on indexing table 
%Filter out the last trial - this is due to EEGAlignEvent_v2 where last
%trials are skipped due to high variability in stopping time 
t50rows = T.Var5 == 50; 
T(t50rows,:) = []; 
save([sp '\EEGStructArm' strFile], 'T','-append'); 
