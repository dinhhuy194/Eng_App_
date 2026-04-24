$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open("d:\hoc flutter\english_learning_app\EduApp_TaiLieu_PhatTrien.docx")
$text = $doc.Content.Text
$text | Out-File -FilePath "d:\hoc flutter\english_learning_app\EduApp_TaiLieu_PhatTrien.txt" -Encoding UTF8
$doc.Close()
$word.Quit()
Write-Host "Done"
