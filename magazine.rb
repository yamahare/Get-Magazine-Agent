require "date"
require "nokogiri"
require 'mysql2'
require 'uri'
require 'open-uri'
require 'yaml'

class Magazine

  attr_accessor :id, :status_flag, :title, :release_date

  def initialize(id="")
      @id           = id
      @status_flag  = 1 #ステータス(正常)
      @title        = ""
      @release_date = ""

      config = YAML.load_file("config/dbconfig.yml")

      name = config["db"]["host"]
      user = config["db"]["user"]
      pass = config["db"]["pass"]
      db_name = config["db"]["db_name"]

      @@client = Mysql2::Client.new(host: name \
                            , username: user \
                            , password: pass \
                            , database: db_name)
  end

  #-------------------------
  # URLと正規表現の設定を取得
  #-------------------------
  def get_url_and_regex
    query = %{SELECT *
              FROM   url_and_regex
            }
    return @@client.query(query)

  end

  #-------------------------
  # タイトルと発売日が一致するかどうか
  #-------------------------
  def exist?
    query = %{SELECT *
              FROM   titles_and_release_date
              WHERE  release_date = "#{@release_date}"
              AND    title        = "#{@title}"
              AND    magazine_id  = "#{@id}"
            }
    results = @@client.query(query)

    # 取得できた場合、真。取得できなかった場合、偽。
    return results.count != 0
  end
  #-------------------------
  # 雑誌の一番最新のデータとタイトルが一致するのに発売日が異なる場合
  #-------------------------
  def release_date_changed?
    query = %{SELECT *
              FROM   titles_and_release_date 
              WHERE  title        = "#{@title}"
              AND    magazine_id  = "#{@id}"
              AND    release_date <> "#{@release_date}"
              AND    release_date = (SELECT max(release_date)
                                     FROM   titles_and_release_date
                                     WHERE  magazine_id = "#{@id}"
                                    )
            }
    results = @@client.query(query)

    # 取得できた場合、真。取得できなかった場合、偽。
    return results.count != 0
  end
  #-------------------------
  # 週刊誌の発売日を登録
  #-------------------------
  def change_release_date
      # 既存の古い発売日データは論理削除
      query = %{UPDATE titles_and_release_date
              SET del_flag    = 1
                 ,updated_at = "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
              WHERE  title        = "#{@title}"
              AND    magazine_id  = "#{@id}"
              AND    release_date <> "#{@release_date}"
              AND    release_date = (select tmp.max_date
                                    from (SELECT max(release_date) max_date
                                          FROM   titles_and_release_date
                                          WHERE  magazine_id = "#{@id}"
                                          ) tmp
                                    )
              }
      results = @@client.query(query)

      # 新規の発売日データを登録
      insert
  end
  #-------------------------
  # 週刊誌の発売日を登録
  #-------------------------
  def insert
      query = %{INSERT INTO titles_and_release_date 
                (magazine_id, title, release_date, updated_at,created_at)
                VALUES ("#{@id}"
                      , "#{@title}"
                      , "#{@release_date}"
                      , "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
                      , "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
                      )
              }
      results = @@client.query(query)
  end

  #-------------------------
  # ステータスを更新
  #-------------------------
  def update_status
    query = %{UPDATE magazines
              SET status       = "#{@status_flag}"
                 ,updated_at = "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
              WHERE id = "#{@id}"
              }
    results = @@client.query(query)
  end

  #-------------------------
  # main 雑誌のパース
  #-------------------------
  def parse(file_path, target, title_reg, release_reg)
    doc = File.open(file_path) { |f| Nokogiri::HTML.parse(f) }
    str = doc.css(target).inner_html
    str.tr!("０-９", "0-9")
    p str

    # NOを取得
    if str.match(title_reg) then
      p $1
      @title = $1
      @title.gsub!(/<.+?>/,'')
    else #取得できなかった場合、ステータスを不正にする
      #p "タイトル取得出来ません"
      @status_flag = 0
    end

    # 発売日を取得
    if str.match(release_reg) then
      p "#{$1}月#{$2}日"
      get_month  = $1.to_i
      get_date   = $2.to_i
      this_year  = Time.now.year
      this_month = Time.now.month

      #発売月が今月より小さい場合来年とみなす
      if this_month > get_month then
        @release_date = Date.new(this_year + 1, get_month, get_date)
      #今月と発売月を引いた絶対値が9以上の場合,去年とみなす
      #例：今月が2月なのに発売日が11月
      elsif (get_month - this_month).abs >= 9 then
        @release_date = Date.new(this_year - 1, get_month, get_date)
      else
        @release_date = Date.new(this_year, get_month, get_date)
      end
    else
      #p "発売日取得出来ません"
      @status_flag = 0
    end
  end

  #-------------------------
  # 雑誌の画像から日付を取得（未完成）
  #-------------------------
  def getpic(file_path, target, url, title_reg, release_reg)
    doc = File.open(file_path) { |f| Nokogiri::HTML.parse(f) }
    path     = doc.css(target)[0][:src]
    #パスからファイル名だけ抜き出す
    filename = File.basename(URI.parse(path).path)
    # urlとpathを連結していい感じにURLを生成してくれる
    pic_url    = URI.join(url,path)
    # 画像の保存先dir
    target_dir = File.dirname(file_path)

    open(pic_url) { |image|
      File.open("#{target_dir}/#{filename}","wb") do |file|
        file.puts image.read
      end
    }
  end

end
