module Main
    ( main
    ) where

import           Control.Monad.IO.Class       ( liftIO )
import qualified Data.ByteString              as BS
import qualified Data.ByteString.Char8        as C8
import           GitHub.Data.Webhooks.Events  ( IssueCommentEvent(..) )
import           GitHub.Data.Webhooks.Payload ( HookIssueComment(..) )
import           Network.Wai                  ( Application )
import           Network.Wai.Handler.Warp     ( run )
import           System.Environment           ( lookupEnv )

-- Using servant and servant-github-webhook to serve the API
import           Servant
import qualified Servant.GitHub.Webhook       as SGH
import           Servant.GitHub.Webhook       ( GitHubEvent, GitHubSignedReqBody, RepoWebhookEvent(..) )

newtype GitHubKey = GitHubKey (forall result. SGH.GitHubKey result)

gitHubKey :: IO BS.ByteString -> GitHubKey
gitHubKey k = GitHubKey (SGH.gitHubKey k)

instance HasContextEntry '[GitHubKey] (SGH.GitHubKey result) where
    getContextEntry (GitHubKey x :. _) = x


type IssueCommentHookAPI
    =  GitHubEvent '[ 'WebhookIssueCommentEvent ]
    :> GitHubSignedReqBody '[JSON] IssueCommentEvent
    :> Post '[JSON] ()

issueCommentHook :: RepoWebhookEvent -> ((), IssueCommentEvent) -> Handler ()
issueCommentHook _ ev = liftIO $
    print $ (show . whIssueCommentBody . evIssueCommentPayload . snd) ev

main :: IO ()
main = do
    port <- maybe 8080 read <$> lookupEnv "PORT"
    key <- maybe mempty C8.pack <$> lookupEnv "KEY"
    putStrLn $ "Server is starting on port " ++ show port ++ " using test secret " ++ show key
    putStrLn $ "Perhaps run 'ngrok http " ++ show port ++ "' for a forwarding address"
    run port (app (gitHubKey $ pure key))

app :: GitHubKey -> Application
app key
  = serveWithContext
    (Proxy :: Proxy IssueCommentHookAPI)
    (key :. EmptyContext)
    issueCommentHook
