unit UserScript;

var
  // iniファイル出力用変数
  slExport: TStringList;
  targetFileName, followerFileName: string;
  
  // イニシャル処理で設定・使用する変数
  targetID: string;
  useFormID, removeFollowerNPC, isInputProvided: boolean;

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

function FindNPCPlacedRecord(baseNPCRecord: IwbMainRecord;): IwbMainRecord;
var
  refRecord: IwbMainRecord;
  i: integer;
  findRecordFlag: boolean;
begin
  Result := nil;
  findRecordFlag := false;
  for i := 0 to Pred(ReferencedByCount(baseNPCRecord)) do begin
    // Scan for records that reference the replaced NPC record
    refRecord := ReferencedByIndex(baseNPCRecord, i);
    //AddMessage(IntToStr(i) + '. RefernceRecord Signature: ' + Signature(refRecord));
    if Signature(refRecord) = 'ACHR' then begin
      Result := refRecord;
      findRecordFlag := true;
      break;
    end;
  end;
  if findRecordFlag then
    AddMessage('Success to find ACHR record.')
  else
    AddMessage('Failed to find ACHR record.');
end;

function RemoveLeadingZeros(const s: string): string;
var
  i: Integer;
begin
  i := 1;
  // 先頭の '0' をスキップ
  while (i <= Length(s)) and (s[i] = '0') do
    Inc(i);
  // すべてが '0' の場合は '0' を返す
  if i > Length(s) then
    Result := '0'
  else
    Result := Copy(s, i, Length(s) - i + 1);
end;

function FileNameByFormID(const formIDStr: string): string;
var
  formID, i: cardinal;
  f: IInterface;
  rec: IInterface;
begin
  Result := '';
  // StrToIntでは負数になってしまうので、StrToInt64で変換し、Cardinal型で受け取る。
  formID := StrToInt64('$' + formIDStr);
//  AddMessage('Converted Form ID: ' + IntToStr(formID));

  // 0始まりに加えて、Skyrim.exeの分も足してループ回数を減らす。
  for i := 0 to FileCount - 2 do begin
    f := FileByLoadOrder(i);
//    AddMessage('Searching file name: ' + GetFileName(f));
    rec := RecordByFormID(f, formID, True);
//    AddMessage('Record Form ID: ' + IntToStr(GetLoadOrderFormID(rec)));
    // Form IDを取得する関数はいくつかあるが、ロードオーダーを含めたForm IDを取得できるのはGetLoadOrderFormID
    if Assigned(rec) and GetLoadOrderFormID(rec) = formID then begin
      Result := GetFileName(f);
      Exit;
    end;
  end;
  
  AddMessage('Entered Form ID can''t be find. Check the Form ID is correct and target file is loaded.');

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
    opts.Add('Remove follower NPCs in the game');

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
      removeFollowerNPC := true;
      
  finally
    opts.Free;
    selected.Free;
  end;

  // 見た目を変更するNPCのIDを入力する
  if useFormID then begin
    repeat
      isInputProvided := InputQuery('Target Form ID Input', 'Enter the target Form ID in 8 digits.', targetID);
      if not isInputProvided then begin
        MessageDlg('Cancel was pressed, aborting the script.', mtInformation, [mbOK], 0);
        Result := -1;
        Exit;
      end;
  //    AddMessage('now targetID:' + targetID);
      if targetID = '' then begin // 入力のチェック
        MessageDlg('Input is empty. Please reenter Target Form ID.', mtInformation, [mbOK], 0);
        validInput := false;
      end
      else begin
        if InputValidationFormID(targetID) then begin
          AddMessage('The input is valid.');
          AddMessage('Target Form ID set to: ' + targetID);
          validInput := true;
        end
        else begin
          MessageDlg('The input is invalid.', mtInformation, [mbOK], 0);
          validInput := false;
        end;
      end;
        
      if validInput = false then begin
        targetID := '';
      end;
    until (isInputProvided) and (validInput);
    
    // ターゲットNPCが所属するファイル名を取得
    targetFileName := FileNameByFormID(targetID);
    if targetFileName = '' then begin
      MessageDlg('Target file can''t find. Script will be aborted.', mtInformation, [mbOK], 0);
      Result := -1;
      Exit;
    end
    else
      AddMessage('Target file name set to: ' + targetFileName);
    
  end
  else begin
      repeat
      isInputProvided := InputQuery('Target Editor ID Input', 'Enter the Target Editor ID.', targetID);
      if not isInputProvided then begin
        MessageDlg('Cancel was pressed, aborting the script.', mtInformation, [mbOK], 0);
        Result := -1;
        Exit;
      end;
  //    AddMessage('now targetID:' + targetID);
      if targetID = '' then begin // 入力のチェック
        MessageDlg('Input is empty. Please reenter Target Editor ID.', mtInformation, [mbOK], 0);
        validInput := false;
      end
      else begin
        AddMessage('Target Editor ID set to: ' + targetID);
        validInput := true;
      end;
        
      if validInput = false then begin
        targetID := '';
      end;
    until (isInputProvided) and (validInput);
    
  end;
  
end;

function Process(e: IInterface): integer;

var
  flags: IInterface;
  NPC_ACHRRecord: IwbMainRecord;
  followerFormID: Cardinal;
  targetFormID, targetEditorID, followerEditorID: string; // レコードID関連
  trimedTargetFormID, trimedFollowerFormID, slTargetID, slFollowerID, wnamID, slSkinID: string; // SkyPatcher iniファイルの記入用
begin
  targetFormID := '';
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
    targetFormID := targetID
    //AddMessage('Target Form ID: ' + IntToHex(targetFormID, 8));
    //AddMessage('Target Form ID: ' + IntToStr(targetFormID));
   // AddMessage('Target Filename: ' + targetFileName);
  end
  else begin
    targetEditorID := targetID;
    //AddMessage('Target Editor ID: ' + targetEditorID);
  end;
  
  // フォロワーNPCのForm ID, Editor IDを取得
  followerFormID := GetElementNativeValues(e, 'Record Header\FormID');
   //AddMessage('Follower Form ID: ' + IntToStr(followerFormID));
   //AddMessage('Follower Form ID: ' + IntToHex(followerFormID, 8));
  followerEditorID := GetElementEditValues(e, 'EDID');
  // AddMessage('Follower Editor ID: ' + followerEditorID);
  
  // オプションに応じて、フォロワーNPCの配置レコードを削除
  if removeFollowerNPC then begin
    // Skip if ACHR record already exists
    AddMessage('Check if this NPC is already placed...');
    NPC_ACHRRecord := FindNPCPlacedRecord(e);
    if not Assigned(NPC_ACHRRecord) then begin
      AddMessage('The NPC is not placed.');
    end
    else begin
      remove(NPC_ACHRRecord);
      AddMessage('NPC place record has removed.');
    end;
  end;
  
  // 出力ファイル用の配列操作
  if useFormID then begin
    // ゼロパディングしない形式のForm IDを設定、iniファイルへの記入はこちらを利用する  
    if  UpperCase(Copy(targetFormID, 1, 2)) = 'FE' then
      trimedTargetFormID := Copy(targetFormID, 6, 8)
    else
      trimedTargetFormID := Copy(targetFormID, 3, 8);
      
    trimedTargetFormID := RemoveLeadingZeros(trimedTargetFormID);
    
    trimedFollowerFormID := IntToHex(followerFormID and  $FFFFFF, 1);
    
    slTargetID := trimedTargetFormID + '~' + targetFileName;
    slFollowerID := trimedFollowerFormID + '~' + followerFileName;
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
    slSkinID := wnamID + '~' + followerFileName;
    
  
  slExport.Add('#' + GetElementEditValues(e, 'FULL'));
  slExport.Add('match=' + slTargetID + ' swap=' + slFollowerID + #13#10);

end;

function Finalize: integer;
var
  dlgSave: TSaveDialog;
  ExportFileName, saveDir: string;
begin
  if slExport.Count <> 0 then 
  begin
  // SkyPatcher iniファイルの出力処理
  saveDir := DataPath + 'Follower RDF NPC Replacer Converter\SKSE\Plugins\RaceSwap\';
  if not DirectoryExists(saveDir) then
    ForceDirectories(saveDir);

  dlgSave := TSaveDialog.Create(nil);
    try
      dlgSave.Options := dlgSave.Options + [ofOverwritePrompt];
      dlgSave.Filter := 'Txt (*.txt)|*.txt';
      dlgSave.InitialDir := saveDir;
      dlgSave.FileName := followerFileName + '.txt';
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
