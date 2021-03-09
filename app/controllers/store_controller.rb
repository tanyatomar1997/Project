class StoreController < ApplicationController
  def index
    def index
      @products = Product.order(:title)
    end
  end
end
