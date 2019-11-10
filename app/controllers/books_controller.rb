# frozen_string_literal: true

class BooksController < ApplicationController
  def new
    unless user_signed_in?
      flash[:warning] = '漫画を探すにはログインが必要です。'
      redirect_to user_session_path
    end

    @books = []
    @title = params[:title]
    @page = if params[:pageselect].present?
              params[:pageselect]
            else
              1
            end

    if @title.present?
      @sort_type = params[:sortselect]

      results = RakutenWebService::Books::Book.search(
        title: @title,
        booksGenreId: '001001',
        outOfStockFlag: '1',
        sort: @sort_type,
        page: @page
      )
      results.each do |result|
        book = Book.new(read(result))
        @books << book unless book.title =~ /コミックカレンダー|(巻|冊|BOX)セット/
      end
      @no_results = '漫画は見つかりませんでした。' if @books.blank?
    end
    @search_result = "検索結果：「#{@title}」を表示しています。"
    @books = Kaminari.paginate_array(@books).page(params[:page]).per(30)
  end

  def create
    @book = Book.find_or_initialize_by(isbn: params[:isbn])
    unless @book.persisted?
      results = RakutenWebService::Books::Book.search(
        isbn: @book.isbn,
        outOfStockFlag: '1'
      )
      @book = Book.new(read(results.first))
      @book.save
    end
  end

  def show
    unless user_signed_in?
      flash[:warning] = '漫画の詳細ページをみるにはログインが必要です。'
      redirect_to user_session_path
    end

    @book = Book.find_or_initialize_by(isbn: params[:isbn])

    @book_subs_count = Book.joins(:subscribes).group(:book_id).count[@book.id]
    @book_subs_count = 0 if @book_subs_count.nil?

    @book_favs_count = Book.joins(:favorites).group(:book_id).count[@book.id]
    @book_favs_count = 0 if @book_favs_count.nil?

    unless @book.persisted?
      results = RakutenWebService::Books::Book.search(
        isbn: @book.isbn,
        outOfStockFlag: '1'
      )
      @book = Book.new(read(results.first))
      @book.save
    end
    if Bookseries.find_by(title: @book.series).nil?
      @bookseries = Bookseries.new(title: @book.series)
      @bookseries.save
    end
  end

  def ranking
    unless user_signed_in?
      flash[:warning] = '登録数ランキングをみるにはログインが必要です。'
      redirect_to user_session_path
    end
    @book_subs_count = Book.joins(:subscribes).group(:book_id).count
    @book_subs_ids = Hash[@book_subs_count.sort_by { |_, v| -v }].keys
    @book_ranking = Book.where(id: @book_subs_ids).order("FIELD(id, #{@book_subs_ids.join(',')})").page(params[:page]).per(15)
    if params[:page].nil?
      @rank = 1
    else
      page = params[:page].to_i
      @rank = (page - 1) * 10 + 1
    end
  end

  def review_ranking
    unless user_signed_in?
      flash[:warning] = '高評価ランキングをみるにはログインが必要です。'
      redirect_to user_session_path
    end
    @book_review_average = Book.joins(:reviews).group(:book_id).average(:point)
    book_review_ids = Hash[@book_review_average.sort_by { |_, v| -v }].keys
    @review_ranking = Book.where(id: book_review_ids).order("FIELD(id, #{book_review_ids.join(',')})").page(params[:page]).per(15)
    if params[:page].nil?
      @rank = 1
    else
      page = params[:page].to_i
      @rank = (page - 1) * 10 + 1
    end
  end

  private

  def read(result)
    title = result['title']
    author = result['author']
    publisherName = result['publisherName']
    url = result['itemUrl']
    salesDate = result['salesDate']
    isbn = result['isbn']
    image_url = result['mediumImageUrl'].gsub('?_ex=120x120', '?_ex=350x350')
    series = view_context.series_create(result['title'])
    salesint = result['salesDate'].gsub(/年|月|日/, '').to_i
    {
      title: title,
      author: author,
      publisherName: publisherName,
      url: url,
      salesDate: salesDate,
      isbn: isbn,
      image_url: image_url,
      series: series,
      salesint: salesint
    }
  end
end
