# frozen_string_literal: true

require_relative 'openfoodfacts/additive'
require_relative 'openfoodfacts/brand'
require_relative 'openfoodfacts/category'
require_relative 'openfoodfacts/city'
require_relative 'openfoodfacts/contributor'
require_relative 'openfoodfacts/country'
require_relative 'openfoodfacts/entry_date'
require_relative 'openfoodfacts/faq'
require_relative 'openfoodfacts/ingredient'
require_relative 'openfoodfacts/ingredient_that_may_be_from_palm_oil'
require_relative 'openfoodfacts/label'
require_relative 'openfoodfacts/language'
require_relative 'openfoodfacts/last_edit_date'
require_relative 'openfoodfacts/locale'
require_relative 'openfoodfacts/manufacturing_place'
require_relative 'openfoodfacts/mission'
require_relative 'openfoodfacts/number_of_ingredients'
require_relative 'openfoodfacts/nutrition_grade'
require_relative 'openfoodfacts/origin'
require_relative 'openfoodfacts/packager_code'
require_relative 'openfoodfacts/packaging'
require_relative 'openfoodfacts/period_after_opening'
require_relative 'openfoodfacts/press'
require_relative 'openfoodfacts/product'
require_relative 'openfoodfacts/product_state'
require_relative 'openfoodfacts/purchase_place'
require_relative 'openfoodfacts/store'
require_relative 'openfoodfacts/trace'
require_relative 'openfoodfacts/user'
require_relative 'openfoodfacts/version'

require 'json'
require 'nokogiri'
require 'open-uri'
require 'net/http'

module Openfoodfacts
  DEFAULT_LOCALE = Locale::GLOBAL
  DEFAULT_DOMAIN = 'openfoodfacts.org'

  # Network timeouts (seconds). Open Food Facts can be slow, and write
  # operations (product update, image upload) are not always wrapped in an
  # external timeout by callers, so we bound every request here.
  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 10

  class << self
    # Configurable API domain. Falls back to the OPENFOODFACTS_DOMAIN env var
    # (handy to target the staging server openfoodfacts.net), then to the
    # default production domain. Also settable at runtime, e.g. in tests.
    attr_writer :domain

    def domain
      @domain || ENV.fetch('OPENFOODFACTS_DOMAIN', DEFAULT_DOMAIN)
    end

    # User-Agent mandated by Open Food Facts on every call, including writes
    # (format: "AppName/Version (contact)"). Read from OPENFOODFACTS_USER_AGENT.
    def user_agent
      ENV.fetch('OPENFOODFACTS_USER_AGENT', nil)
    end

    # Centralized HTTP GET with User-Agent header and timeouts.
    #
    def http_get(url)
      options = { open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT }
      ua = user_agent
      options['User-Agent'] = ua if ua
      URI.parse(url).open(options)
    end

    # Centralized form-urlencoded HTTP POST with User-Agent header and timeouts.
    # Unlike Net::HTTP.post_form, this carries the User-Agent OFF requires on
    # write operations.
    #
    def http_post(url, params)
      uri = URI.parse(url)
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(params)
      ua = user_agent
      request['User-Agent'] = ua if ua
      perform(uri, request)
    end

    # Centralized multipart HTTP POST (e.g. product image upload) with
    # User-Agent header and timeouts. `parts` is an array as accepted by
    # Net::HTTPHeader#set_form, e.g.
    #   [['code', '123'], ['imgupload_front', io, { filename: 'x.jpg', content_type: 'image/jpeg' }]]
    #
    def http_post_multipart(url, parts)
      uri = URI.parse(url)
      request = Net::HTTP::Post.new(uri)
      request.set_form(parts, 'multipart/form-data')
      ua = user_agent
      request['User-Agent'] = ua if ua
      perform(uri, request)
    end

    # Return locale from link
    #
    def locale_from_link(link)
      Locale.locale_from_link(link)
    end

    # Get locales
    #
    def locales
      Locale.all
    end

    # Get product
    #
    def product(barcode, locale: DEFAULT_LOCALE)
      Product.get(barcode, locale: locale)
    end

    # Return product API URL
    #
    def product_url(barcode, locale: DEFAULT_LOCALE)
      Product.url(barcode, locale: locale)
    end

    private

    def perform(uri, request)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.start { |conn| conn.request(request) }
    end
  end
end
