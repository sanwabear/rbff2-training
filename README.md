# リアルバウト餓狼伝説2 トレーニングモードLuaスクリプト

1998年に発売されたネオジオの対戦格闘ゲーム、餓狼伝説シリーズ7作目、リアルバウトシリーズ3作目にあたる「リアルバウト餓狼伝説2 NEW COMMERS」のトレーニングモードを実現するためのLuaスクリプトです。
このプロジェクトは *mame-rr-scripts* の実装の一部を含みます。


## スタートガイド

プロジェクトをダウンロードしてトレーニングモードを実行するまでの手順を説明します。

### 動作環境

次の環境で動作確認しています。
BIOSに関しては UNIVERSAL-BIOS 4.0 をご利用ください。
本スクリプトはAES版での動作確認を行っています。

1. Windows11
2. MAME 0.260 64-bit
3. UNIVERSAL-BIOS 4.0を含む neogeo.zip
4. rbff2h.zip 


### 必要条件

トレーニングモードを実行するためには、以下のものが必要になります。

 1.  本プラグインを利用できるアーケードゲームエミュレーターMAME
	Windows 10上で動作するMAME 0.222 64-bit Windows版でプラグインの開発と動作確認を行っています。
	2020年7月現在では、次のリンクからダウンロードすることができます: [MAME]

2.  リアルバウト餓狼伝説2ロムデータ
	[GOG]、 [DMM] または [Humble Bundle]で販売されている、移植ソフトからデータを取り出すことができます。
	ゲームを購入して、あなたの環境にインストールしたあと、インストールディレクトリのなかある rbff2.zip がロムデータです。
	BIOSである neogeo.zip も同じ場所から取り出すことができます。
	rbff2.zip を rbff2h.zip にリネームして使用してください。

3. ネオジオのBIOSデータ
	前述のロムデータと同じく[GOG]、 [DMM] または [Humble Bundle]で販売されている、移植ソフトからデータを入手できます。
	GOGかDMMで入手できる neogeo.zip に UNIVERSAL-BIOS 4.0 を追加して利用してください。
	[UNIVERSAL-BIOS]から入手できます。

4. コマンド表示の処理でMAMEに含まれるdataプラグインを利用します。

[GOG]:https://www.gog.com/
[DMM]:https://games.dmm.com/
[Humble Bundle]:https://www.humblebundle.com/
[MAME]:https://www.mamedev.org/release.html
[UNIVERSAL-BIOS]:http://unibios.free.fr/
[ATE]:http://glorious.r.ribbon.to/pach_ATE/pach_ATE.html

### インストール方法

1. ダウンロードしたファイルを確認します。
	![ダウンロード後](https://github.com/sanwabear/rbff2training-doc/blob/master/how_to_pic/1_MAME%E3%81%A8BIOS%E3%83%80%E3%82%A6%E3%83%B3%E3%83%AD%E3%83%BC%E3%83%89%E5%BE%8C.png?raw=true "ダウンロード後")
	- この手順ではMAMEのアーカイブ(`mame0222b_64bit.exe`)と`uni-bios-40.zip`を使います。
2. MAMEのインストールディレクトリを作成します。
	![ディレクトリ作成](https://github.com/sanwabear/rbff2training-doc/blob/master/how_to_pic/2_MAME%E5%85%A5%E3%82%8C%E4%BD%9C%E6%88%90.png?raw=true "ディレクトリ作成")
3. MAMEのアーカイブを解凍します。
	![解凍](https://github.com/sanwabear/rbff2training-doc/blob/master/how_to_pic/3_MAME%E8%A7%A3%E7%AD%94.png?raw=true "解凍")
	- ↓ 解凍
	![解凍後](https://github.com/sanwabear/rbff2training-doc/blob/master/how_to_pic/4_%E8%A7%A3%E5%87%8D%E3%81%8A%E3%82%8F%E3%82%8A.png?raw=true "解凍後")
4. ゲームのROMデータとBIOSデータをMAMEのromsディレクトリにコピーします。
	![ROMデータ](https://github.com/sanwabear/rbff2training-doc/blob/master/how_to_pic/5_%E3%83%AD%E3%83%A0%E3%82%B3%E3%83%94%E3%83%BC.png?raw=true "ROMデータ")
	- ↓ コピー
	![ROMデータコピー後](https://github.com/sanwabear/rbff2training-doc/blob/master/how_to_pic/6_%E3%83%AD%E3%83%A0%E3%82%B3%E3%83%94%E3%83%BC%E5%BE%8C.png?raw=true "ROMデータコピー後")
	- この手順ではDMMのインストール先ディレクトリからコピーします。
	- *コピー後にファイル名をrbff2h.zipに変更してください。*
5. ダウンロードしたUNIVERSAL-BIOS 4.0のBIOSデータを`neogeo.zip`の中に含めます。
	![UNIBIOSコピー](https://github.com/sanwabear/rbff2training-doc/blob/master/how_to_pic/7_BIOS%E3%82%B3%E3%83%94%E3%83%BC.png?raw=true "UNIBIOSコピー")
	- ↓ コピー
	
	![UNIBIOSコピー後](https://github.com/sanwabear/rbff2training-doc/blob/master/how_to_pic/8_BIOS%E3%82%B3%E3%83%94%E3%83%BC%E5%BE%8C.png?raw=true "UNIBIOSコピー後")
6. 本スクリプトをダウンロードします。
	![スクリプト](https://github.com/sanwabear/rbff2training-doc/blob/master/how_to_pic/9_%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%97%E3%83%88%E3%83%80%E3%82%A6%E3%83%B3%E3%83%AD%E3%83%BC%E3%83%89.png?raw=true "スクリプト")
	- ↓ ダウンロード
	
	![スクリプトコピー](https://github.com/sanwabear/rbff2training-doc/blob/master/how_to_pic/10_%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%97%E3%83%88%E3%82%B3%E3%83%94%E3%83%BC.png?raw=true "スクリプトコピー")
	- ↓ コピー
	
	![スクリプトコピー後](https://github.com/sanwabear/rbff2training-doc/blob/master/how_to_pic/11_%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%97%E3%83%88%E3%82%B3%E3%83%94%E3%83%BC%E5%BE%8C.png?raw=true "スクリプトコピー後")
7. rbff2trainingディレクトリにある起動バッチからMAMEを起動します。
    - rbff2h.bat ... トレーニングモードでの起動
    - rbff2h_notr.bat ... 通常起動
8. Enjoy!


## トレーニングモード

1. 1人用であそべます。
2. ゲームを開始します。
3. 1プレイヤーのキャラクター、2プレイヤーのキャラクターを選択します。
4. 対戦がトレーニングモード状態で開始します。
5. スタートボタンで開くメニューからオプションを選択できます。


## 著者

 [Jesuszilla]様が開発した[mame-rr-scripts]から次のスクリプトを複製、改造して取り込んでいます。
 * fighting-OSD.lua
 * garou-hitboxes.lua
 * scrolling-input-display.lua

 [AoiSaya]様が開発した[FlashAir_UTF8toSJIS]から次のスクリプトを複製、改造して取り込んでいます。
 同スクリプトどおり変換テーブルファイルは https://github.com/mgo-tec/UTF8_to_Shift_JIS を使用しています。
 * UTF8toSJIS
 * Utf8Sjis.tbl

[Jesuszilla]:https://github.com/Jesuszilla
[mame-rr-scripts]:https://github.com/Jesuszilla/mame-rr-scripts
[AoiSaya]:https://github.com/AoiSaya
[FlashAir_UTF8toSJIS]:https://github.com/AoiSaya/FlashAir_UTF8toSJIS

その他のスクリプトは@ym2601 (https://github.com/sanwabear)が開発しました。


## ライセンス

このプロジェクトは MITライセンスの元にライセンスされています。 
詳細は LICENSE.md をご覧ください。
