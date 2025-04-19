unit UserScript;

interface
implementation
uses xEditAPI, SysUtils, StrUtils, Windows;
uses 'Forms','Controls','StdCtrls','CheckLst','Dialogs';

var
  // iniファイル出力用変数
  slExport: TStringList;
  targetFileName, followerFileName: string;
  
  // イニシャル処理で設定・使用する変数
  targetID: string;
  useFormID, leaveFollowerNPC, replaceGender, replaceRace, replaceVoiceType, isInputProvided: boolean;

function ShowCheckboxForm(const options: TStringList; out selected: TStringList): Boolean;
var
  form: TForm;
  checklist: TCheckListBox;
  btnOK, btnCancel: TButton;
  i: Integer;
begin
  Result := False;

  form := TForm.Create(nil);
  try
    form.Caption := 'Select Options';
    form.Width := 350;
    form.Height := 300;
    form.Position := poScreenCenter;

    checklist := TCheckListBox.Create(form);
    checklist.Parent := form;
    checklist.Align := alTop;
    checklist.Height := 200;

    // 選択肢を追加
    for i := 0 to options.Count - 1 do begin
      checklist.Items.Add(options[i]);
    end;

    btnOK := TButton.Create(form);
    btnOK.Parent := form;
    btnOK.Caption := 'OK';
    btnOK.ModalResult := mrOk;
    btnOK.Width := 75;
    btnOK.Top := checklist.Top + checklist.Height + 10;
    btnOK.Left := (form.ClientWidth div 2) - btnOK.Width - 10;

    btnCancel := TButton.Create(form);
    btnCancel.Parent := form;
    btnCancel.Caption := 'Cancel';
    btnCancel.ModalResult := mrCancel;
    btnCancel.Width := 75;
    btnCancel.Top := btnOK.Top;
    btnCancel.Left := (form.ClientWidth div 2) + 10;

    form.BorderStyle := bsDialog;
    form.Position := poScreenCenter;

    if form.ShowModal = mrOk then
    begin
      Result := True;
      for i := 0 to checklist.Items.Count - 1 do
        if checklist.Checked[i] then
          selected.Add('True')
        else
          selected.Add('False');
    end;
  finally
    form.Free;
  end;
end;

function InputValidationFormID(const s: string): Boolean;
var
  i: Integer;
  ch: Char;
begin
  Result := true;
  if Length(s) = 8 then begin
    for i := 1 to Length(s) do
    begin
      ch := s[i];
      if not ((ch >= 'A') and (ch <= 'F') or
              (ch >= 'a') and (ch <= 'f') or
              (ch >= '0') and (ch <= '9')) then
      begin
        AddMessage('Only numbers from 0 to 9 and letters from A to F can be entered.');
        Result := false;
        Break;
      end;
    end;
  end
  else begin
    AddMessage('The number of digits entered is invalid. Please enter 8 digits.');
    Result := false;
  end;
end;

function Initialize: integer;
var
  validInput : boolean;
  opts, selected: TStringList;
  i: Integer;
begin
  slExport            := TStringList.Create;

  useFormID           := false;
  isInputProvided     := false;
  
  opts                := TStringList.Create;
  selected            := TStringList.Create;
  
  Result              := 0;

  // 各オプションの設定
  try
    opts.Add('Use Form ID for config file output');
    opts.Add('Leave follower NPCs in the game');
    opts.Add('Replace gender');
    opts.Add('Replace race');
    opts.Add('Replace voice type');

    if ShowCheckboxForm(opts, selected) then
    begin
      AddMessage('You selected:');
      for i := 0 to selected.Count - 1 do
        AddMessage(opts[i] + ' - ' + selected[i]);
    end
    else begin
      AddMessage('Selection was canceled.');
      Result := -1;
      Exit;
    end;
    

    // 出力ファイルに使うのはFormIDとEditorIDのどちらか
    if selected[0] = 'True' then
      useFormID := true;
      
    // フォロワーNPCを残すかどうか
    if selected[1] = 'True' then
      leaveFollowerNPC := 'true';
      
    // 性別を変更するか
    if selected[2] = 'True' then
      replaceGender := true;
      
    // 種族を変更するか
    if selected[3] = 'True' then
      replaceRace := true;
      
    // Voice Typeを変更するか
    if selected[4] = 'True' then
      replaceVoiceType := true;
      
  finally
    opts.Free;
    selected.Free;
  end;

  // 見た目を変更するNPCのIDを入力する
  repeat
    isInputProvided := InputQuery('Target ID Input', 'Enter the Target ID.', targetID);
    if not isInputProvided then begin
      MessageDlg('Cancel was pressed, aborting the script.', mtInformation, [mbOK], 0);
      Result := -1;
      Exit;
    end;
//    AddMessage('now targetID:' + targetID);
    if targetID = '' then begin // 入力のチェック
      MessageDlg('Input is empty. Please reenter Target ID.', mtInformation, [mbOK], 0);
      validInput := false;
    end
    else begin
      if useFormID then begin
        if InputValidationFormID(targetID) then begin
          AddMessage('The input is valid.');
          validInput := true;
        end
        else begin
          MessageDlg('The input is invalid.', mtInformation, [mbOK], 0);
          validInput := false;
        end;
      end
      else begin
        AddMessage('The input is valid.');
        validInput := true;
      end;
    end;
      
    if validInput = false then begin
      targetID := '';
    end;

  until (isInputProvided) and (validInput);
  
  AddMessage('Target ID set to: ' + targetID);

  // リプレイス先のNPCが所属するプラグイン名を入力させる
  if useFormID then begin
    repeat
      isInputProvided := InputQuery('Target filename Input', 'Enter the Target filename with extension.', targetFileName);
      if not isInputProvided then begin
        MessageDlg('Cancel was pressed, aborting the script.', mtInformation, [mbOK], 0);
        Result := -1;
        Exit;
      end;
  //    AddMessage('now Target filename:' + Target filename);
      if targetFileName = '' then begin // 入力のチェック
        MessageDlg('Input is empty. Please reenter Target filename.', mtInformation, [mbOK], 0);
        validInput := false;
      end
      else begin
        AddMessage('Target filename: ' + targetFileName);
        validInput := true;
      end;
        
      if validInput = false then begin
        targetFileName := '';
      end;

    until (isInputProvided) and (validInput);
  end;
  
end;

function Process(e: IInterface): integer;

var
  targetFormID: integer;
  followerFormID, targetEditorID, followerEditorID: string; // レコードID関連
  trimedTargetFormID, trimedFollowerFormID, slTargetID, slFollowerID, wnamID, slSkinID: string; // SkyPatcher iniファイルの記入用
begin
  targetFormID := 0;
  targetEditorID := '';

  // NPCレコードでなければスキップ
  if Signature(e) <> 'NPC_' then begin
    AddMessage(GetElementEditValues(e, 'EDID') + ' is not NPC record.');
    Exit;
  end;

  // Mod名を取得（フォロワーレコードが所属するファイル名）
  followerFileName := GetFileName(GetFile(e));

  // ターゲットNPCのFormID,EditorIDを取得
  if useFormID then begin
    targetFormID := StrToInt('$' + targetID);
    //AddMessage('Target Form ID: ' + IntToHex(targetFormID and  $FFFFFF, 1));
   // AddMessage('Target Filename: ' + targetFileName);
  end
  else begin
    targetEditorID := targetID;
    //AddMessage('Target Editor ID: ' + targetEditorID);
  end;
  
  // フォロワーNPCのForm ID, Editor IDを取得
  followerFormID := IntToHex64(GetElementNativeValues(e, 'Record Header\FormID') and  $FFFFFF, 8);
  // AddMessage('New record Form ID: ' + followerFormID);
  followerEditorID := GetElementEditValues(e, 'EDID');
  // AddMessage('Created new record with Editor ID: ' + followerEditorID);
  

  // 出力ファイル用の配列操作
  if useFormID then begin
    // ゼロパディングしない形式のForm IDを設定、iniファイルへの記入はこちらを利用する
    trimedTargetFormID := IntToHex(targetFormID and  $FFFFFF, 1);
    trimedFollowerFormID := IntToHex(followerFormID and  $FFFFFF, 1);
    
    slTargetID := targetFileName + '|' + trimedTargetFormID;
    slFollowerID := followerFileName + '|' + trimedFollowerFormID;
  end
  else begin
    slTargetID := targetEditorID;
    slFollowerID := followerEditorID;
  end;

  // NPCレコードのWNAMフィールドが設定されていたらWNAMのスキンを反映
  wnamID := IntToHex(GetElementNativeValues(e, 'WNAM') and  $FFFFFF, 1);
  //  AddMessage('wnamID is:' + wnamID);
  if wnamID = '0' then
    slSkinID := slFollowerID
  else
    slSkinID := followerFileName + '|' + wnamID;

  slExport.Add(';' + GetElementEditValues(e, 'FULL'));
  slExport.Add('filterByNpcs=' + slTargetID + ':copyVisualStyle=' + slFollowerID + ':skin=' + slSkinID + #13#10);


end;

function Finalize: integer;
var
  dlgSave: TSaveDialog;
  ExportFileName, saveDir: string;
begin
  if slExport.Count <> 0 then 
  begin
  // SkyPatcher iniファイルの出力処理
  saveDir := DataPath + 'Follower SkyPatcher NPC Replacer Converter\SKSE\Plugins\SkyPatcher\npc\Follower SkyPatcher NPC Replacer Converter\';
  if not DirectoryExists(saveDir) then
    ForceDirectories(saveDir);

  dlgSave := TSaveDialog.Create(nil);
    try
      dlgSave.Options := dlgSave.Options + [ofOverwritePrompt];
      dlgSave.Filter := 'Ini (*.ini)|*.ini';
      dlgSave.InitialDir := saveDir;
      dlgSave.FileName := followerFileName + '.ini';
  if dlgSave.Execute then 
    begin
      ExportFileName := dlgSave.FileName;
      AddMessage('Saving ' + ExportFileName);
      slExport.SaveToFile(ExportFileName);
    end;
  finally
    dlgSave.Free;
    end;
  end;
    slExport.Free;
end;

end.
