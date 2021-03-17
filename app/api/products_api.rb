# frozen_string_literal: true

module Version4
  class ProductAPI < Grape::API # :nodoc:
    namespace :products do
      route_param :products_id, regexp: UUID_REGEX do
        after_validation do
          @product = products(params[:product_id])
          access_validation(@product)
        end

        desc 'Returns all products for a Store'
        params do
          optional :page, type: Integer, default: 1
          optional :per, type: Integer, default: 20
          optional :filter_by, default: 'mine'
          optional :query
          optional :offset_no, type: Integer
          optional :limit_no, type: Integer
          requires :status, type: String,
                   allow_blank: false
        end
        get 'products' do
          declared_params = declared(params, include_missing: false)

          query = {}
          query[:status] = declared_params['status']

          filter = params[:query].present? ? params[:query] : '*'

          filter_clients(query) unless @client_id.blank?

          if declared_params['filter_by'] == 'mine'
            query[:created_by] = @user.id
          elsif declared_params['filter_by'] == 'others'
            query[:created_by] = { not: @user.id }
          elsif declared_params['filter_by'] == 'delayed'
            query[:due_date] = { lt: 'now/d' }
          end

          sort = {}
          sort['due_date'] = { :order => 'asc', 'unmapped_type' => 'long' }

          products = product.search(filter,
                                    fields: %w[
              name^2
              description
            ], load: false, where: query,
                                    page: declared_params[:page],
                                    per_page: declared_params[:per])

          { total: products.total_count,
            entities: products,
            page: declared_params[:page] }
        end

        desc 'Returns single product for a site.'
        params do
          requires :id, regexp: UUID_REGEX
        end
        get 'products/:id' do
          product = product.find(params[:id])
          validate_client(product)
          product
        end

        desc 'Create a product for a site'
        params do
          requires :id, regexp: UUID_REGEX,
                   allow_blank: false
          requires :description, allow_blank: false,
                   desc: 'Fill the product Description'
          requires :name, allow_blank: false,
                   desc: 'product Name'
        end
        post :products do
          declared_params = declared(params, include_missing: false)
          declared_params[:client_id] = @client_id if @client_id
          begin
            product = @site.products.find(declared_params[:id])
            product.update_attributes!(declared_params)
          rescue
            product = @site.products.new(declared_params)
            product.save!
          end
          product.attributes.merge('created_by' => product.created_by.id)
        end

        desc 'Update a product.'
        params do
          requires :id, regexp: UUID_REGEX,
                   allow_blank: false
          requires :name, allow_blank: false,
                   desc: 'Fill the product name'
          requires :description, allow_blank: false,
                   desc: 'Fill the product Description'
        end
        put 'products/:id' do
          declared_params = declared(params, include_missing: false)
          product = @site.products.find(declared_params[:id])
          validate_client(product)
          declared_params[:name] = declared_params[:name].strip
          product.update_attributes!(declared_params)
          product
        end

        desc 'Transfer the product'
        params do
          requires :product_id, regexp: UUID_REGEX,
                   allow_blank: false
          requires :email, regexp: EMAIL_REGEX,
                   allow_blank: false
        end
        put 'transfer_product' do
          declared_params = declared(params, include_missing: false)
          tranfer_user = User.find_by_email(declared_params[:email])
          if tranfer_user
            product = @site.products.find(declared_params[:product_id])
            validate_client(product)
            product.update_attributes!(created_by: tranfer_user.id)
            WebMailer.transfer_product_notification_email(@user,
                                                          tranfer_user,
                                                          product).deliver
            receiver = product.created_by.id
            message = "#{@user.fullname} had
                       transferred product(#{product.name})
              to you"
            send_notification(message, [receiver])

            { product: product, status: true,
              user: tranfer_user.fullname }
          else
            { status: false }
          end
        end

        desc 'delete a product'
        params do
          requires :id, regexp: UUID_REGEX,
                   allow_blank: false
          requires :status, allow_blank: false,
                   values: %w[deleted]
        end
        post 'products/:id/:status' do
          declared_params = declared(params, include_missing: false)
          product = @site.products.find(declared_params[:id])
          validate_client(product)
          product.status = declared_params[:status]
          product.save
          product
        end
      end
    end

    desc 'Returns single product for a site.'
    params do
      requires :id, regexp: UUID_REGEX
    end
    get 'products/:id' do
      product = product.find(params[:id])
      validate_client(product)
      product
    end

    desc 'Returns all products without site'
    params do
      optional :page, type: Integer, default: 1
      optional :per, type: Integer, default: 20
      optional :filter_by, default: 'mine'
      optional :query
      optional :offset_no, type: Integer
      optional :limit_no, type: Integer
      requires :status, allow_blank: false
    end
    get 'products' do
      declared_params = declared(params, include_missing: false)
      user = User.find_by(id: @user_id)

      query = {}
      query[:data_proxy_id] = user.sites.map(&:id)
      query[:status] = declared_params['status']

      filter = params[:query].present? ? params[:query] : '*'

      filter_clients(query) unless @client_id.blank?

      if declared_params['filter_by'] == 'mine'
        query[:created_by] = @user.id
      elsif declared_params['filter_by'] == 'others'
        query[:created_by] = { not: @user.id }
      elsif declared_params['filter_by'] == 'delayed'
        query[:due_date] = { lt: 'now/d' }
      end

      sort = {}
      sort['due_date'] = { :order => 'desc', 'unmapped_type' => 'long' }

      products = product.search(filter,
                                fields: %w[
          name^2
          description
        ], load: false, where: query,
                                page: declared_params[:page],
                                per_page: declared_params[:per])

      { total: products.total_count,
        entities: products,
        page: declared_params[:page] }
    end
  end
end
# rubocop:enable Metrics/BlockLength
