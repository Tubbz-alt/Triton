function dt_ship_batch
% dtShip_batch(BaseDir, DataFiles, PARAMS, DetParams, varargin)
%
% Run the long time ship detection algorithm on a set of files which are
% members of the LTSA
%
% BaseDir - common prefix for all files, use '' or [] for no prefix
% DataFiles - List of files to be processed
% PARAMS - Structure representing an LTSA
%
% Optional arguments:
% 'Viewpath', {'dir1', 'dir2', ... }
%               List of directories to be viewpathed.  When searching
%               for files, each directory in the cell array is examined
%               for the file, and the first one encountered is used.
%               New files are always written relative to the first
%               directory in the viewpath.
%
% Maintained by CVS - do not modify
% $Id: dtShip_batch.m,v 1 2017/28/02 asolsonaberga
global REMORA

% detection parameters (%%%%%%%%% parameters to add in the settings file)
% % % % REMORA.ship_dt.settings.REWavExt= '(\.x)?\.wav';   % data files must end in this regular expression
% % % % REMORA.ship_dt.settings.RELtsaExt = '.s';   % Ship - Long term detection label extension

% get detection parameters
sec2dnum = 60*60*24; % conversion factor to get from seconds to matlab datenum
durWind = REMORA.ship_dt.settings.durWind;
slide = REMORA.ship_dt.settings.slide;
errorRange = REMORA.ship_dt.settings.errorRange;
tave = REMORA.ship_dt.ltsa.tave;
minPassage = REMORA.ship_dt.settings.minPassage/sec2dnum;

tic;  % Note start time

% Initialize
populateTimes = [];
populateLabels = {};
newperc = 0;

% how many windows will be used to process ltsa
TotalWindows = ceil(REMORA.ship_dt.ltsa.durtot/durWind);

disp('Start processing...')
fprintf('Running Ship batch detection for %d files\n',REMORA.ship_dt.ltsa.nxwav)

% get ltsa window motion parameters
dnumSnippet = REMORA.ship_dt.ltsa.dnumStart(1);

for itr1 = 1:TotalWindows
    
    %%% Detect ships 
    % Apply detector to the central window (of size durWind) and to the
    % overlapping windows of "slide" seconds before and after start of the 
    % central window
    
    % Read the spectral data of the snippet of data and apply detector
    % Central Window
    [pwr,startIndex,startBin] = fn_pwrSnippet(dnumSnippet); 
    [ships,labels,~] = dt_ship_signal(pwr,0);
    dnumShips = (ships./sec2dnum)*tave + dnumSnippet; % convert to actual times
    
    % Previous Window
    dnumPrevSnippet = dnumSnippet - datenum([0 0 0 0 0 slide]);
    
    % If earlier than start of ltsa, previous window will be the same like the central window
    if dnumPrevSnippet < REMORA.ship_dt.ltsa.start.dnum
       dnumPrevSnippet = REMORA.ship_dt.ltsa.start.dnum; 
    end
    [pwr,~,~] = fn_pwrSnippet(dnumPrevSnippet); 
    [shipsPrev,labelsPrev,~] = dt_ship_signal(pwr,0);
    dnumShipsPrev = (shipsPrev./sec2dnum)*tave + dnumPrevSnippet; % convert to actual times
    
    % Posterior window
    dnumPostSnippet = dnumSnippet + datenum([0 0 0 0 0 slide]);
    
    % If past the end of ltsa, posterior window will be the same like the central window
    if dnumPostSnippet > REMORA.ship_dt.ltsa.end.dnum
       dnumPostSnippet = dnumSnippet; 
    end
    [pwr,~,~] = fn_pwrSnippet(dnumPostSnippet); 
    [shipsPost,labelsPost,~] = dt_ship_signal(pwr,0);
    dnumShipsPost = (shipsPost./sec2dnum)*tave + dnumPostSnippet;
    
    
    %%% Compare overlapping windows
    % Select detections that appear at central window and at least in one
    % of the overlapping windows, if not detected in the central window
    % because is cut at the edge, get times from the overlapping window
    selectShips = [];
    selectLabels = {};
    % create combination
    comb = ~[isempty(dnumShips) isempty(dnumShipsPrev) isempty(dnumShipsPost)];
    if isequal(comb,[1 1 1]) || isequal(comb,[1 1 0]) || isequal(comb,[1 0 1])
        for itr2 = 1:size(dnumShips,1)
            if  sum([~isempty(dnumShipsPrev) & abs(dnumShips(itr2,1) - dnumShipsPrev(:,1)) <= errorRange | ...
                    abs(dnumShips(itr2,2) - dnumShipsPrev(:,2)) <= errorRange ; ...
                    ~isempty(dnumShipsPost) & abs(dnumShips(itr2,1) - dnumShipsPost(:,1)) <= errorRange | ...
                    abs(dnumShips(itr2,2) - dnumShipsPost(:,2)) <= errorRange])
                selectShips = [selectShips; dnumShips(itr2,:)];
                selectLabels = [selectLabels; labels{itr2}];
            end
        end
        % if there are detection at the edges include them as well
        if size(dnumShips,1) ~= size(dnumShipsPrev,1)
            for itr2prev = 1: size(dnumShipsPrev,1)
                onEdge = find(dnumShipsPrev(itr2prev,1) < dnumSnippet & dnumShipsPrev(itr2prev,2) > dnumSnippet); % start before the central window and the end in the central window
                if onEdge
                    selectShips = [selectShips; dnumSnippet,dnumShipsPrev(itr2prev,2)];
                    selectLabels = [selectLabels; labelsPrev{itr2prev}];
                end
            end
        end
        % if there are detection at the edges include them as well
        if size(dnumShips,1) ~= size(dnumShipsPost,1)
           for itr2post = 1: size(dnumShipsPost,1) 
               endSnippet = dnumSnippet + datenum([0 0 0 0 0 durWind]);
               onEdge = find(dnumShipsPost(itr2post,1) <= endSnippet & dnumShipsPost(itr2post,2) > endSnippet); % the start have to be in the central window and the end passed
               if onEdge
                   selectShips = [selectShips; dnumShipsPost(itr2post,1), endSnippet];
                   selectLabels = [selectLabels; labelsPost{itr2post}];
               end
           end
        end
    end
    if isequal(comb,[0 1 0]) || isequal(comb,[0 1 1])
        % detection at the left edge of the window
        for itr3 = 1:size(dnumShipsPrev,1)
            onEdge = find(dnumShipsPrev(itr3,1) < dnumSnippet & dnumShipsPrev(itr3,2) > dnumSnippet); % start before the central window and the end in the central window
            if onEdge
                selectShips = [selectShips; dnumSnippet,dnumShipsPrev(itr3,2)]; 
                selectLabels = [selectLabels; labelsPrev{itr3}];
            end
        end
    end
    if isequal(comb,[0 0 1]) || isequal(comb,[0 1 1])
        % detection at the right edge of the window
        for itr4 = 1:size(dnumShipsPost,1)
            endSnippet = dnumSnippet + datenum([0 0 0 0 0 durWind]);
            onEdge = find(dnumShipsPost(itr4,1) <= endSnippet & dnumShipsPost(itr4,2) > endSnippet); % the start have to be in the central window and the end passed
            if onEdge
                selectShips = [selectShips; dnumShipsPost(itr4,1), endSnippet]; 
                selectLabels = [selectLabels; labelsPost{itr4}];
            end
        end
    end

    if ~isempty(selectShips)
        %%% Populate data to save to corresponding files 
        % Convert all ship_s from matlab times to real times
        populateTimes = [populateTimes; selectShips + datenum([2000,0,0])];
        populateLabels = [populateLabels; selectLabels];
    end
    
    % only text will be displayed in command window if number increased
    perc = round(itr1/TotalWindows*100);
    if perc ~= newperc
        newperc = perc; 
        progress = [num2str(newperc),'%'];
        fprintf('   %s completed\n',progress)
    end

    itr1 = itr1 + 1;
    dnumSnippet = fn_getNextTimeWindow(startIndex,startBin);
end

if ~isempty(populateTimes)
    [~,I] = sort(populateTimes(:,1));
    shipTimes = populateTimes(I,:);
    shipLabels = populateLabels(I);
    
    if size(shipTimes,1) > 1
        remove = find((shipTimes(2:end,1) - shipTimes(1:end-1,2)) < minPassage)';
        if ~isempty(remove)
            selStart = shipTimes(:,1); selStart(remove+1) = [];
            selEnd = shipTimes(:,2); selEnd(remove) = [];
            shipTimes = [selStart, selEnd];
            % compare if labels are different
            reLabel = ~strcmp(shipLabels(remove+1),shipLabels(remove));
            % different label, one was detected as ship, so keep it as
            % ship, end is deleted
            shipLabels(remove(reLabel == 1)) = {'ship'};
            shipLabels(remove(reLabel == 1)+1) = [];
            % same label
            shipLabels(remove(reLabel == 0)+1) = [];    
        end
    end
    % save all detections with real datenums in a mat file
    filename = split(REMORA.ship_dt.ltsa.infile,'.ltsa');
    matname = ['Ship_detections_',filename{1},'.mat'];
    save(fullfile(REMORA.ship_dt.settings.outDir,matname),'shipTimes',...
        'shipLabels','-mat','-v7.3');
    fprintf('Detections saved at: %s\n',fullfile(REMORA.ship_dt.settings.outDir,matname));
    
    % save labels
    if REMORA.ship_dt.settings.saveLabels
        labelname = ['Ship_labels_',filename{1},'.tlab'];
        ioWriteLabel(fullfile(REMORA.ship_dt.settings.outDir,labelname), shipTimes - datenum([2000 0 0 0 0 0]), shipLabels, 'Binary', true);
        fprintf('Labels saved at: %s\n',fullfile(REMORA.ship_dt.settings.outDir,labelname));
    end

else
    fprintf('No detections in file: %s\n',...
        fullfile(REMORA.ship_dt.ltsa.inpath,REMORA.ship_dt.ltsa.infile))
end

fprintf('LTSA batch detection completed (%d files, processing time: %s)\n', ...
    REMORA.ship_dt.ltsa.nxwav, sectohhmmss(toc));

