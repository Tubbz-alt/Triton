function bp_init_batch_figure

global REMORA

defaultPos = [0.25,0.25,0.3,0.6];
REMORA.fig.bp.detector = figure( ...
    'NumberTitle','off', ...
    'Name','Fin Whale Index Detector - v1.0',...
    'Units','normalized',...
    'MenuBar','none',...
    'Position',defaultPos, ...
    'Visible', 'on');

% Detection Settings pulldown
REMORA.bp.menu = uimenu(REMORA.fig.bp.detector,'Label','&Load Settings',...
    'Enable','on','Visible','on');

% Spectrogram load/save params
uimenu(REMORA.bp.menu,'Label','&Select Detector Settings File',...
    'Callback','bp_gui_pulldown(''settingsLoadBatch'')');