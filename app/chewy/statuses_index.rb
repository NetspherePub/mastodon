# frozen_string_literal: true

class StatusesIndex < Chewy::Index
  include DatetimeClampingConcern

  settings index: index_preset(refresh_interval: '30s', number_of_shards: 5), analysis: {
    filter: {
      english_stop: {
        type: 'stop',
        stopwords: '_english_',
      },

      english_stemmer: {
        type: 'stemmer',
        language: 'english',
      },

      english_possessive_stemmer: {
        type: 'stemmer',
        language: 'possessive_english',
      },

      korean_pos: {
        type: 'nori_part_of_speech',
        # Preserve semantic modifiers and prefixes (MAG, MM, XPN).
        stoptags: %w(
          E
          IC
          J
          MAJ
          SP
          SSC
          SSO
          SC
          SE
          XSA
          XSN
          XSV
          UNA
          NA
          VSV
        ),
      },
    },

    analyzer: {
      verbatim: {
        tokenizer: 'uax_url_email',
        filter: %w(lowercase),
      },

      content: {
        tokenizer: 'standard',
        filter: %w(
          lowercase
          asciifolding
          cjk_width
          elision
          english_possessive_stemmer
          english_stop
          english_stemmer
        ),
      },

      korean: {
        tokenizer: 'nori_tokenizer_mixed',
        filter: %w(
          korean_pos
          nori_readingform
          lowercase
        ),
      },

      hashtag: {
        tokenizer: 'keyword',
        filter: %w(
          word_delimiter_graph
          lowercase
          asciifolding
          cjk_width
        ),
      },
    },

    tokenizer: {
      nori_tokenizer_mixed: {
        # https://www.elastic.co/guide/en/elasticsearch/plugins/current/analysis-nori-tokenizer.html
        type: 'nori_tokenizer',
        decompound_mode: 'mixed',
        discard_punctuation: 'true',
      },
    },
  }

  index_scope ::Status.unscoped.kept.without_reblogs.includes(:media_attachments, :local_mentioned, :local_favorited, :local_reblogged, :local_bookmarked, :tags, preview_cards_status: :preview_card, preloadable_poll: :local_voters), delete_if: ->(status) { status.searchable_by.empty? }

  root date_detection: false do
    field(:id, type: 'long')
    field(:account_id, type: 'long')
    field(:text, type: 'text', analyzer: 'verbatim', value: ->(status) { status.searchable_text }) { field(:stemmed, type: 'text', analyzer: 'content') }
    field(:text_ko, type: 'text', analyzer: 'korean', value: ->(status) { status.searchable_text if status.language.to_s.match?(/\A(?:ko|kor)(?:[-_].+)?\z/i) })
    field(:tags, type: 'text', analyzer: 'hashtag',  value: ->(status) { status.tags.map(&:display_name) })
    field(:searchable_by, type: 'long', value: ->(status) { status.searchable_by })
    field(:language, type: 'keyword')
    field(:properties, type: 'keyword', value: ->(status) { status.searchable_properties })
    field(:created_at, type: 'date', value: ->(status) { clamp_date(status.created_at) })
  end
end
