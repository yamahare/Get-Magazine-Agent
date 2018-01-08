require "./magazine.rb"

#変数初期化、Magazineクラスをアロケート
pre_id = ""
magazine = Magazine.allocate

# URLと正規表現の設定取得
maga_conf = Magazine.new
results   = maga_conf.get_url_and_regex

#--------------------------
#   設定数の数だけ繰り返し
#--------------------------
results.each_with_index do |row, i|

  # 画像から発売日取得（未完成）
  if row["getpicflg"] == 1 then
=begin
    magazine.getpic(row["file_path"]\
                  ,row["target"]\
                  ,row["url"]\
                  ,Regexp.new(row["title_reg"])\
                  ,Regexp.new(row["release_reg"])\
                  )
    pre_id = row["magazine_id"]
=end
    next;
  end

  # マガジンIDが切り替わったら
  if pre_id != row["magazine_id"] then
    # 繰り返しの初回でなければ、マガジンインスタンスのステータスを更新
    if i != 0 then 
      magazine.update_status
    end
    # 新しいマガジンインスタンスを生成
    magazine = Magazine.new(row["magazine_id"]) 
  end
  
  p "-----------------------------"
  p row["magazine_id"]
  p row["file_path"]
  # サイトから発売日とタイトルをパース
  magazine.parse(row["file_path"]\
                ,row["target"]\
                ,Regexp.new(row["title_reg"])\
                ,Regexp.new(row["release_reg"])\
                )

  # パースが正常であった場合
  if magazine.status_flag == 1 then 

    # 同じデータが存在しない場合
    unless magazine.exist? then

      # 発売日が変わった場合更新
      if magazine.release_date_changed? then magazine.change_release_date
      # 新規登録
      else magazine.insert
      end

    end

  end

  # 繰り返しの最後の場合、マガジンインスタンスのステータスを更新
  if results.count == i+1 then
    magazine.update_status
  end

  # 現在のマガジンIDを変数に格納
  pre_id = row["magazine_id"]

end
