# frozen_string_literal: true

require "codebase_rag/version"
require "dotenv"

# .envファイルを読み込む
Dotenv.load

# CodebaseRag モジュール
# Rubyコードベース用のRAG（Retrieval-Augmented Generation）システム
module CodebaseRag
  class Error < StandardError; end

  # 自動的に必要なファイルを読み込む
  module Presentation
    autoload :CLI, "codebase_rag/presentation/cli"
    autoload :MCPServer, "codebase_rag/presentation/mcp_server"
  end

  module Domain
    module Entities
      autoload :CodeChunk, "codebase_rag/domain/entities/code_chunk"
      autoload :Embedding, "codebase_rag/domain/entities/embedding"
      autoload :EmbeddingResult, "codebase_rag/domain/entities/embedding"
      autoload :Metadata, "codebase_rag/domain/entities/metadata"
      autoload :RagMetadata, "codebase_rag/domain/entities/metadata"
      autoload :CodebaseRagServerOptions, "codebase_rag/domain/entities/metadata"
    end

    module Services
      autoload :Chunker, "codebase_rag/domain/services/chunker"
      autoload :EmbeddingServiceInterface, "codebase_rag/domain/services/embedding_service_interface"
      autoload :LLMServiceInterface, "codebase_rag/domain/services/llm_service_interface"
    end

    module Repositories
      autoload :VectorStoreInterface, "codebase_rag/domain/repositories/vector_store_interface"
    end
  end

  module Application
    module Services
      autoload :QueryService, "codebase_rag/application/services/query_service"
      autoload :RagBuilder, "codebase_rag/application/services/rag_builder"
      autoload :RagQuery, "codebase_rag/application/services/rag_query"
    end
  end

  module Infrastructure
    module External
      autoload :OpenAIEmbeddingService, "codebase_rag/infrastructure/external/openai_embedding_service"
      autoload :OpenAILLMService, "codebase_rag/infrastructure/external/openai_llm_service"
    end

    module Repositories
      autoload :VectorStore, "codebase_rag/infrastructure/repositories/vector_store"
    end

    module Server
      autoload :CodebaseRagServer, "codebase_rag/infrastructure/server/server"
    end
  end
end
