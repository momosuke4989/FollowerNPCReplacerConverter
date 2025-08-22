unit UserScript;

var
  // iniファイル出力用変数
  slExport: TStringList;
  targetFileName, followerFileName: string;
  
  // イニシャル処理で設定・使用する変数
  targetID: string;
  useFormID, removeFollowerNPC, replaceSkin, replaceGender, replaceRace, replaceVoiceType, isInputProvided: boolean;

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
    
    // skinオプションはデフォルトをオンに設定
    checklist.Checked[2] := True;

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

function FindRecordByRecordID(const recordID, signature: string; useFormID: boolean): IwbMainRecord;
var
  formID, i: cardinal;
  editorID: string;
  f:  IwbFile;
  rec: IwbMainRecord;
  npcRecordGroup: IwbGroupRecord;
begin
  Result := nil;
  
  if useFormID then begin
    // StrToIntでは負数になってしまうので、StrToInt64で変換し、Cardinal型で受け取る。
    formID := StrToInt64('$' + recordID);
  //  AddMessage('Converted Form ID: ' + IntToStr(formID));
  end
  else
    editorID := recordID;

  // 0始まりに加えて、Skyrim.exeの分も足してループ回数を減らす。
  for i := 0 to FileCount - 2 do begin
    f := FileByLoadOrder(i);
//    AddMessage('Searching file name: ' + GetFileName(f));
    if useFormID then begin
      rec := RecordByFormID(f, formID, True);
  //    AddMessage('Record Form ID: ' + IntToStr(GetLoadOrderFormID(rec)));
      // Form IDを取得する関数はいくつかあるが、ロードオーダーを含めたForm IDを取得できるのはGetLoadOrderFormID
      if Assigned(rec) and (GetLoadOrderFormID(rec) = formID) then begin
        AddMessage('Record is found by entered Form ID');
        if (Signature(rec) = signature) then begin
          AddMessage('Record signature is correct.');
          Result := rec;
        end
        else
          AddMessage('Record signature is incorrect.');
        break;
      end;
    end
    else begin
      npcRecordGroup := GroupBySignature(f, signature);
      rec := MainRecordByEditorID(npcRecordGroup, editorID);
      if Assigned(rec) then begin
        AddMessage('Record is found by entered Editor ID');
        if (Signature(rec) = signature)  then begin
          AddMessage('Record signature is correct.');
          Result := rec;
        end
        else
          AddMessage('Record signature is incorrect.');
        break;
      end;
    end;
  end;
  if Assigned(Result) then
    AddMessage('Target Record is found')
  else
    AddMessage('No target record found for the entered ID. Check the entered ID is correct and target file is loaded.');

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
    opts.Add('Replace skin');

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
      
    // 肌テクスチャを変更するか
    if selected[2] = 'True' then
      replaceSkin := true;
      
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
  followerFlags, targetFlags, followerRaceElement, followerVoiceTypeElement, targetRaceElement, targetVoiceTypeElement: IInterface;
  targetRecord, NPC_ACHRRecord, followerRaceRecord, followerVoiceTypeRecord, targetRaceRecord, targetVoiceTypeRecord: IwbMainRecord;
  followerFormID: Cardinal;
  recordSignature, targetFormID, targetEditorID, followerEditorID: string; // レコードID関連
  commentOutSkin, commentOutGender, commentOutRace, commentOutVoiceType: string;
  trimedTargetFormID, trimedFollowerFormID, slTargetID, slFollowerID, wnamID, slSkinID, slGender, slRace, slVoiceType: string; // SkyPatcher iniファイルの記入用
  sameGender, sameRace, sameVoiceType: boolean;
begin
  targetFormID := '';
  targetEditorID := '';
  
  commentOutSkin := '';
  
  recordSignature := 'NPC_';

  // NPCレコードでなければスキップ
  if Signature(e) <> 'NPC_' then begin
    AddMessage(GetElementEditValues(e, 'EDID') + ' is not NPC record.');
    Exit;
  end;

  // Mod名を取得（フォロワーレコードが所属するファイル名）
  followerFileName := GetFileName(GetFile(e));
  
  // ターゲットNPCのFormID,EditorIDからターゲットNPCのレコードを取得
  targetRecord := FindRecordByRecordID(targetID, 'NPC_', useFormID);
  if not Assigned(targetRecord) then begin
    AddMessage('Target record not found. Processing aborted.');
    Exit;
  end;
  AddMessage('Found record: Editor ID: ' + GetElementEditValues(targetRecord, 'EDID') + ' Name: ' + GetElementEditValues(targetRecord, 'FULL'));
  targetFileName := GetFileName(targetRecord);
  AddMessage('Target file name set to: ' + targetFileName);
  

  // ターゲットNPCのFormID,EditorIDを取得
  targetFormID := IntToHex64(GetElementNativeValues(targetRecord, 'Record Header\FormID') and  $FFFFFF, 8);
    //AddMessage('Target Record Form ID: ' + targetFormID);
  targetEditorID := GetElementEditValues(targetRecord, 'EDID');
    //AddMessage('Target Record Editor ID: ' + targetEditorID);
  
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

  // 肌、性別、種族、声のオプションに応じて、各行をコメントアウトさせる
  if replaceSkin = false then
    commentOutSkin := ';';
  
  // フォロワーNPCの性別、種族、音声タイプを取得
  followerFlags := ElementByPath(e, 'ACBS - Configuration');
  followerRaceElement := ElementByPath(e, 'RNAM');
  followerRaceRecord := LinksTo(followerRaceElement);
  followerVoiceTypeElement := ElementByPath(e, 'VTCK');
  followerVoiceTypeRecord := LinksTo(followerVoiceTypeElement);
  
  // ターゲットNPCの性別、種族、音声タイプを取得
  targetFlags := ElementByPath(targetRecord, 'ACBS - Configuration');
  targetRaceElement := ElementByPath(targetRecord, 'RNAM');
  targetRaceRecord := LinksTo(targetRaceElement);
  targetVoiceTypeElement := ElementByPath(targetRecord, 'VTCK');
  targetVoiceTypeRecord := LinksTo(targetVoiceTypeElement);
  
  // フォロワーNPCとターゲットNPCの性別、種族、音声タイプを比較して、結果をフラグに反映する。
  if GetElementEditValues(targetFlags, 'Flags\Female') = GetElementEditValues(followerFlags, 'Flags\Female') then
    sameGender := true
  else
    sameGender := false;
    
  if GetElementNativeValues(followerRaceRecord, 'Record Header\FormID') = GetElementNativeValues(targetRaceRecord, 'Record Header\FormID') then
    sameRace := true
  else
    sameRace := false;
  
  if GetElementNativeValues(followerVoiceTypeRecord, 'Record Header\FormID') = GetElementNativeValues(targetVoiceTypeRecord, 'Record Header\FormID') then
    sameVoiceType := true
  else
    sameVoiceType := false;
  
  // 出力ファイル用の配列操作
  if useFormID then begin
    // ゼロパディングしない形式のForm IDを設定、iniファイルへの記入はこちらを利用する  
    if  UpperCase(Copy(targetFormID, 1, 2)) = 'FE' then
      trimedTargetFormID := Copy(targetFormID, 6, 8)
    else
      trimedTargetFormID := Copy(targetFormID, 3, 8);
      
    trimedTargetFormID := RemoveLeadingZeros(trimedTargetFormID);
    
    trimedFollowerFormID := IntToHex(followerFormID and  $FFFFFF, 1);
    
    slTargetID := targetFileName + '|' + trimedTargetFormID;
    slFollowerID := followerFileName + '|' + trimedFollowerFormID;
    slRace  := GetFileName(followerRaceRecord) + '|' + IntToHex(FormID(followerRaceRecord) and  $FFFFFF, 1);
    slVoiceType := GetFileName(followerVoiceTypeRecord) + '|' + IntToHex(FormID(followerVoiceTypeRecord) and  $FFFFFF, 1);
  end
  else begin
    slTargetID := targetEditorID;
    slFollowerID := followerEditorID;
    slRace  := EditorID(followerRaceRecord);
    slVoiceType := EditorID(followerVoiceTypeRecord);
  end;
  
  // 性別フラグを反映する文字列を入力
  if GetElementEditValues(followerFlags, 'Flags\Female') = 1 then
    slGender := ':setFlags=female'
  else
    slGender := ':removeFlags=female';
  
  // NPCレコードのWNAMフィールドが設定されていたらWNAMのスキンを反映。
  // 設定されていない場合はnullでデフォルトボディを指定。
  wnamID := IntToHex(GetElementNativeValues(e, 'WNAM') and  $FFFFFF, 1);
  //  AddMessage('wnamID is:' + wnamID);
  if wnamID = '0' then
    slSkinID := 'null'
  else
    slSkinID := followerFileName + '|' + wnamID;
    
  
  slExport.Add(';' + GetElementEditValues(targetRecord, 'FULL'));
  slExport.Add('filterByNpcs=' + slTargetID + ':copyVisualStyle=' + slFollowerID);
  slExport.Add(commentOutSkin + 'filterByNpcs=' + slTargetID + ':skin=' + slSkinID);
  
  if not sameGender then
    slExport.Add('filterByNpcs=' + slTargetID + slGender);
  
  if not sameRace then
    slExport.Add('filterByNpcs=' + slTargetID + ':race=' + slRace);
  
  if not sameVoiceType then
    slExport.Add('filterByNpcs=' + slTargetID + ':voiceType=' + slVoiceType);
  
  slExport.Add(#13#10);

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
